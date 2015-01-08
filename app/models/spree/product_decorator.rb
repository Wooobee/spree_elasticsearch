module Spree
  Product.class_eval do
    # Inner class used to query elasticsearch. The idea is that the query is dynamically build based on the parameters.
    class Product::ElasticsearchQuery
      include ::Virtus.model

      attribute :from, Integer, default: 0
      attribute :price_min, Float
      attribute :price_max, Float
      attribute :properties, Hash
      attribute :query, String
      attribute :taxons, Array

      # Method that creates the actual query based on the current attributes.
      # The idea is to always to use the following schema and fill in the blanks.
      # {
      #   query: {
      #     filtered: {
      #       query: {
      #         query_string: { query: , fields: [] }
      #       }
      #       filter: {
      #         and: [
      #           { terms: { taxons: [] } },
      #           { terms: { properties: [] } }
      #         ]
      #       }
      #     }
      #   }
      #   filter: { range: { price: { lte: , gte: } } },
      #   sort: [],
      #   from: ,
      #   size: ,
      #   facets:
      # }
      
    end

    include Concerns::Indexable



    # Used at startup when creating or updating the index with all type mappings
    def self.type_mapping
      {
        id: { type: 'string', index: 'not_analyzed' },
        name: {
          fields: {
            name: { type: 'string', analyzer: 'snowball', boost: 100 },
            untouched: { include_in_all: false, index: "not_analyzed", type: "string" }
          },
          type: "multi_field"
        },
        description: { type: 'string', analyzer: 'snowball' },
        available_on: { type: 'date', format: 'dateOptionalTime', include_in_all: false },
        updated_at: { type: 'date', format: 'dateOptionalTime', include_in_all: false },
        price: { type: 'double' },
        properties: { type: 'string', index: 'not_analyzed' },
        sku: { type: 'string', analyzer: 'sku' },
        taxons: { type: 'string', index: 'not_analyzed' }
      }
    end

    # Used when creating or updating a document in the index
    def to_hash
      result = {
        'id' => id,
        'name' => name,
        'description' => description,
        'available_on' => available_on,
        'updated_at' => updated_at,
        'price' => price,
      }
      result['sku'] = sku unless sku.try(:empty?)
      result['properties'] = product_properties.map{|pp| "#{pp.property.name}||#{pp.value}"} unless product_properties.empty?
      unless taxons.empty?
        # in order for the term facet to be correct we should always include the parent taxon(s)
        result['taxons'] = taxons.map do |taxon|
          taxon.self_and_ancestors.map(&:permalink)
        end.flatten
      end
      # add variants information
      if variants.length > 0
        result['variants'] = []
        variants.each do |variant|
          result['variants'] << variant.attributes
        end
      end
      result
    end

    # Override from concern for better control.
    # If the product is available, index. If the product is destroyed (deleted_at attribute is set), delete from index.
    def update_index
      begin
        unless deleted?
          self.index
        else
          self.remove_from_index
        end
      rescue Elasticsearch::Transport::Transport::Errors => e
        Rails.logger.error e
      end
    end
  end
end
