module Listable
  class ViewManager

    class << self
      def prefixed_view_name(name)
        prefix << name.underscore.pluralize
      end

      def prefix
        'lstble_'  
      end

      def listables
        @@listables
      end

      def add_listable(view_name, model_name, model_scope_name)
        @@listables ||= {}
        @@listables[view_name] ||= {}
        @@listables[view_name][model_name] = model_scope_name
      end

      def listable_view?(name)
        name.start_with? prefix
      end

      def create_views
        return if listables.nil?
        ActiveRecord::Base.transaction do
          drop_views # First drop all listable views to get a fresh start
          listables.each do |view_name, query_info|
            queries = []
            view_name = prefixed_view_name(view_name.to_s) # Appending a prefix to views
            query_info.each do |model_name, scope|
              puts "scope: #{scope}"
              model_class = Kernel.const_get(model_name)
              table_name = model_class.table_name
              query = model_class.select_as("#{table_name}.id" => :listable_id) # Always begin selection with the original model ID
              query = query.send(scope) # Appends selection from scope
              query = query.select(["#{table_name}.created_at", "#{table_name}.updated_at"]) # Include Rails' timestamps in view
              query = query.select("CAST('#{model_name}' AS char(#{model_name.length})) COLLATE utf8_unicode_ci AS listable_type ") # Finish with the original model name, needed for the polymorphic relation

              queries << query
            end

            create_sql = "CREATE VIEW #{view_name.to_s.pluralize} AS "
            queries.map!(&:to_sql) # Compile the arel queries to sql
            create_sql << queries * ' UNION ' # Combines the queries with union
            puts create_sql

            ActiveRecord::Base.connection.execute create_sql
          end
        end
      end

      def drop_views
        ActiveRecord::Base.connection.views.each do |name|
          ActiveRecord::Base.connection.execute "DROP VIEW #{name}"
        end
      end
    end
  end  
end