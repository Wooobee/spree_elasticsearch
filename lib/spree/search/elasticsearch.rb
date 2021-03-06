module Spree
  module Search
    # The following search options are available.
    #   * taxon
    #   * keywords in name or description
    #   * properties values
    class Elasticsearch <  Spree::Core::Search::Base
      include ::Virtus.model

      attribute :query, String
      attribute :price_min, Float
      attribute :price_max, Float
      attribute :taxons, Array
      attribute :properties, Hash
      attribute :per_page, String
      attribute :page, String

      def initialize(params)
        self.current_currency = Spree::Config[:currency]
        prepare(params)
      end

      def retrieve_products
        from = (@page - 1) * Spree::Config.products_per_page
        search_result = Spree::Product.__elasticsearch__.search(
          Spree::Product::ElasticsearchQuery.new(
            query: query,
            taxons: taxons,
            from: from,
            price_min: price_min,
            price_max: price_max,
            properties: properties
          ).to_hash
        )
        search_result.page(page).records
      end

      protected

      # converts params to instance variables
      def prepare(params)
        @query = params[:keywords]
        @taxons = params[:taxon]
        if params[:search]
          # price
          @price_min = params[:search][:price][:min].to_f
          @price_max = params[:search][:price][:max].to_f
          # properties
          @properties = params[:search][:properties]
        end

        @per_page = (params[:per_page].to_i <= 0) ? Spree::Config[:products_per_page] : params[:per_page].to_i
        @page = (params[:page].to_i <= 0) ? 1 : params[:page].to_i
      end
    end
  end
end