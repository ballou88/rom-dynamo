require 'uri'
require 'rom/gateway'
require 'rom/dynamo/dataset'
require 'rom/dynamo/commands'

module Rom
  module Dynamo
    class Gateway < ROM::Gateway
      def initialize(uri)
        uri = URI.parse(uri)
        @connection = Aws::DynamoDB::Client.new(endpoint: uri)
        @prefix = uri.path.gsub('/', '')
        @datasets = {}
      end

      def use_logger(logger)
        @logger = logger
      end

      def dataset(name)
        name = "#{@prefix}#{name}"
        @datasets[name] ||= Dataset.new(name, @connection)
      end

      def dataset?(name)
        name = "#{@prefix}#{name}"
        list = connection.list_tables
        list[:table_names].include?(name)
      end

      def [](name)
        @datasets[name]
      end
    end
  end
end
