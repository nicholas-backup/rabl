module Rabl
  module Helpers
    # data_object(data) => <AR Object>
    # data_object(@user => :person) => @user
    # data_object(:user => :person) => @_object.send(:user)
    # data_object(:get_user => :person, 1) => @_object.send(:get_user, 1)
    # data_object(:get_users => :person, [1,2]) => @_object.send(:get_users, 1, 2)
    # data_object(:get_users => :person, [[1,2]]) => @_object.send(:get_users, [1,2])
    def data_object(data, args=[])
      data = (data.is_a?(Hash) && data.keys.size == 1) ? data.keys.first : data
      data.is_a?(Symbol) && @_object ? @_object.send(data, *args) : data
    end

    # data_name(data) => "user"
    # data_name(@user => :person) => :person
    # data_name(@users) => :user
    # data_name([@user]) => "user"
    # data_name([]) => "array"
    def data_name(data, args=[])
      return nil unless data # nil or false
      return data.values.first if data.is_a?(Hash) # @user => :user
      data = @_object.send(data, *args) if data.is_a?(Symbol) && @_object # :address
      if data.respond_to?(:first)
        data_name(data.first).pluralize
      else # actual data object
        object_name = @_collection_name.to_s.singularize if defined? @_collection_name
        object_name ||= data.class.respond_to?(:model_name) ? data.class.model_name.element : data.class.to_s.downcase
        object_name
      end
    end

    # Renders a partial hash based on another rabl template
    # partial("users/show", :object => @user)
    def partial(file, options={}, &block)
      source, location = self.fetch_source(file, options)
      self.object_to_hash(options[:object], :source => source, :source_location => location, &block)
    end

    # Returns a hash based representation of any data object given ejs template block
    # object_to_hash(@user) { attribute :full_name } => { ... }
    # object_to_hash(@user, :source => "...") { attribute :full_name } => { ... }
    def object_to_hash(object, options={}, &block)
      return object unless is_object?(object)
      engine_options = { :format => "hash", :root => (options[:root] || false), :source_location => options[:source_location]}
      Rabl::Engine.new(options[:source], engine_options).render(@_scope, :object => object, &block)
    end

    # resolve_condition(:if => true) => true
    # resolve_condition(:if => lambda { |m| false }) => false
    # resolve_condition(:unless => lambda { |m| true }) => true
    def resolve_condition(options)
      return true if options[:if].nil? && options[:unless].nil?
      result = options[:if] == true || (options[:if].respond_to?(:call) && options[:if].call(@_object)) if options.has_key?(:if)
      result = options[:unless] == false || (options[:unless].respond_to?(:call) && !options[:unless].call(@_object)) if options.has_key?(:unless)
      result
    end

    # Returns true if obj is not enumerable
    # is_object?(@user) => true
    # is_object?([]) => false
    # is_object?({}) => false
    def is_object?(obj)
      obj && !data_object(obj).is_a?(Enumerable)
    end

    # Returns true if the obj is a collection of items
    def is_collection?(obj)
      obj && data_object(obj).is_a?(Enumerable)
    end

    # Returns source for a given relative file
    # fetch_source("show", :view_path => "...") => "...contents..."
    def fetch_source(file, options={})
      if defined? Rails
        root_path = Rails.root
        view_path = options[:view_path] || File.join(root_path, "app/views/")
        file_path = Dir[File.join(view_path, file + ".*.rabl")].first
      elsif defined? Padrino
        root_path = Padrino.root
        # use Padrino's own template resolution mechanism
        file_path, _ = @_scope.instance_eval { resolve_template(file) }
        # Padrino chops the extension, stitch it back on
        file_path = File.join(@_scope.settings.views, (file_path.to_s + ".rabl"))
      end

      if file_path
        return File.read(file_path.to_s), file_path.to_s
      else
        nil
      end
    end
  end
end
