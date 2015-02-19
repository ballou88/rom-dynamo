module Rom
  module Dynamo
    class Relation < ROM::Relation
      include Enumerable
      forward :restrict, :index_restrict

      def insert(*args)
        dataset.insert(*args)
        self
      end

      def delete(*args)
        dataset.delete(*args)
        self
      end
    end

    class Dataset
      include Equalizer.new(:name, :connection)
      attr_reader :name, :connection
      alias_method :ddb, :connection

      def initialize(name, ddb, conditions = nil)
        @name, @connection = name, ddb
        @conditions = conditions || {}
      end

      ############# READ #############
      def each(&block)
        each_item({
          consistent_read: true,
          key_conditions: @conditions
        }, &block)
      end

      def restrict(query = nil)
        return self if query.nil?
        conds = query_to_conditions(query)
        conds = @conditions.merge(conds)
        dup_as(Dataset, conditions: conds)
      end

      def index_restrict(index, query)
        conds = query_to_conditions(query)
        conds = @conditions.merge(conds)
        dup_as(GlobalIndexDataset, index: index, conditions: conds)
      end

      ############# WRITE #############
      def insert(hash)
        connection.put_item({
          table_name: name,
          item: hash
        })
      end

      def delete(hash)
        connection.delete_item({
          table_name: name,
          key: hash_to_key(hash),
          expected: to_expected(hash),
        })
      end

      ############# HELPERS #############
    private
      def each_item(options, &block)
        puts "Querying #{name} ...\nWith: #{options.inspect}"
        connection.query(options.merge({
          table_name: name
        })).each_page do |page|
          page[:items].each(&block)
        end
      end

      def query_to_conditions(query)
        Hash[query.map do |key, value|
          [key, {
            attribute_value_list: [value],
            comparison_operator:  "EQ"
          }]
        end]
      end

      def to_expected(hash)
        hash && Hash[hash.map do |k, v|
          [k, { value: v }]
        end]
      end

      def hash_to_key(hash)
        table_keys.each_with_object({}) do |k, out|
          out[k] = hash[k] if hash.has_key?(k)
        end
      end

      def table_keys
        @table_keys ||= begin
          resp = ddb.describe_table(table_name: name)
          keys = resp.first[:table][:key_schema]
          keys.map(&:attribute_name)
        end
      end

      def dup_as(klass, opts = {})
        table_keys # To populate keys once at top-level Dataset
        vars = [:@name, :@connection, :@conditions, :@table_keys]
        klass.allocate.tap do |out|
          vars.each { |k| out.instance_variable_set(k, instance_variable_get(k)) }
          opts.each { |k, v| out.instance_variable_set("@#{k}", v) }
        end
      end
    end

    # Dataset queried via a Global Index
    class GlobalIndexDataset < Dataset
      attr_accessor :index

      def each(&block)
        # Pull record IDs from Global Index
        keys = []; each_item({
          key_conditions: @conditions,
          index_name: @index
        }) { |hash| keys << hash_to_key(hash) }

        # Bail if we have nothing
        return if keys.empty?

        # Query for the actual records
        ddb.batch_get_item({
          request_items: { name => { keys: keys } },
        }).each_page do |page|
          out = page[:responses][name]
          out.each(&block)
        end
      end

    end
  end
end