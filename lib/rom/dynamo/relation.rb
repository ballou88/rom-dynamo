module Rom
  module Dynamo
    class Relation < ROM::Relation
      adapter :dynamo
      include Enumerable
      forward :restrict, :index_restrict, :all
    end


    # # Dataset queried via a Global Index
    # class GlobalIndexDataset < Dataset
    #   attr_accessor :index

    #   def each(&block)
    #     # Pull record IDs from Global Index
    #     keys = []; each_item({
    #       key_conditions: @conditions,
    #       index_name: @index
    #     }) { |hash| keys << hash_to_key(hash) }

    #     # Bail if we have nothing
    #     return if keys.empty?

    #     # Query for the actual records
    #     ddb.batch_get_item({
    #       request_items: { name => { keys: keys } },
    #     }).each_page do |page|
    #       out = page[:responses][name]
    #       out.each(&block)
    #     end
    #   end

    # end
  end
end
