# frozen_string_literal: true
#
# = ostruct.rb: OpenStruct implementation
#
# Author:: Yukihiro Matsumoto
# Documentation:: Gavin Sinclair
#
# OpenStruct allows the creation of data objects with arbitrary attributes.
# See OpenStruct for an example.
#

#
# An OpenStruct is a data structure, similar to a Hash, that allows the
# definition of arbitrary attributes with their accompanying values. This is
# accomplished by using Ruby's metaprogramming to define methods on the class
# itself.
#
# == Examples
#
#   require "ostruct"
#
#   person = OpenStruct.new
#   person.name = "John Smith"
#   person.age  = 70
#
#   person.name      # => "John Smith"
#   person.age       # => 70
#   person.address   # => nil
#
# An OpenStruct employs a Hash internally to store the attributes and values
# and can even be initialized with one:
#
#   australia = OpenStruct.new(:country => "Australia", :capital => "Canberra")
#     # => #<OpenStruct country="Australia", capital="Canberra">
#
# Hash keys with spaces or characters that could normally not be used for
# method calls (e.g. <code>()[]*</code>) will not be immediately available
# on the OpenStruct object as a method for retrieval or assignment, but can
# still be reached through the Object#send method or using [].
#
#   measurements = OpenStruct.new("length (in inches)" => 24)
#   measurements[:"length (in inches)"]       # => 24
#   measurements.send("length (in inches)")   # => 24
#
#   message = OpenStruct.new(:queued? => true)
#   message.queued?                           # => true
#   message.send("queued?=", false)
#   message.queued?                           # => false
#
# Removing the presence of an attribute requires the execution of the
# delete_field method as setting the property value to +nil+ will not
# remove the attribute.
#
#   first_pet  = OpenStruct.new(:name => "Rowdy", :owner => "John Smith")
#   second_pet = OpenStruct.new(:name => "Rowdy")
#
#   first_pet.owner = nil
#   first_pet                 # => #<OpenStruct name="Rowdy", owner=nil>
#   first_pet == second_pet   # => false
#
#   first_pet.delete_field(:owner)
#   first_pet                 # => #<OpenStruct name="Rowdy">
#   first_pet == second_pet   # => true
#
# Ractor compatibility: A frozen OpenStruct with shareable values is itself shareable.
#
# == Caveats
#
# An OpenStruct utilizes Ruby's method lookup structure to find and define the
# necessary methods for properties. This is accomplished through the methods
# method_missing and define_singleton_method.
#
# This should be a consideration if there is a concern about the performance of
# the objects that are created, as there is much more overhead in the setting
# of these properties compared to using a Hash or a Struct.
# Creating an open struct from a small Hash and accessing a few of the
# entries can be 200 times slower than accessing the hash directly.
#
# This is a potential security issue; building OpenStruct from untrusted user data
# (e.g. JSON web request) may be susceptible to a "symbol denial of service" attack
# since the keys create methods and names of methods are never garbage collected.
#
# This may also be the source of incompatibilities between Ruby versions:
#
#   o = OpenStruct.new
#   o.then # => nil in Ruby < 2.6, enumerator for Ruby >= 2.6
#
# Builtin methods may be overwritten this way, which may be a source of bugs
# or security issues:
#
#   o = OpenStruct.new
#   o.methods # => [:to_h, :marshal_load, :marshal_dump, :each_pair, ...
#   o.methods = [:foo, :bar]
#   o.methods # => [:foo, :bar]
#
# To help remedy clashes, OpenStruct uses only protected/private methods ending with <code>!</code>
# and defines aliases for builtin public methods by adding a <code>!</code>:
#
#   o = OpenStruct.new(make: 'Bentley', class: :luxury)
#   o.class # => :luxury
#   o.class! # => OpenStruct
#
# It is recommended (but not enforced) to not use fields ending in <code>!</code>;
# Note that a subclass' methods may not be overwritten, nor can OpenStruct's own methods
# ending with <code>!</code>.
#
# For all these reasons, consider not using OpenStruct at all.
#
class OpenStruct
  VERSION = "0.5.6"

  def self.optimized?
    true
  end

  #
  # Creates a new OpenStruct object.  By default, the resulting OpenStruct
  # object will have no attributes.
  #
  # The optional +hash+, if given, will generate attributes and values
  # (can be a Hash, an OpenStruct or a Struct).
  # For example:
  #
  #   require "ostruct"
  #   hash = { "country" => "Australia", :capital => "Canberra" }
  #   data = OpenStruct.new(hash)
  #
  #   data   # => #<OpenStruct country="Australia", capital="Canberra">
  #
  def initialize(hash=nil)
    if hash
      update_to_values!(hash)
    end
  end

  def dup
    # Is this the right way to ensure the singleton class is cloned?
    clone(freeze: false)
  end

  private def update_to_values!(hash) # :nodoc:
    hash.each_pair do |k, v|
      set_ostruct_member_value!(k, v)
    end
  end

  #
  # call-seq:
  #   ostruct.to_h                        -> hash
  #   ostruct.to_h {|name, value| block } -> hash
  #
  # Converts the OpenStruct to a hash with keys representing
  # each attribute (as symbols) and their corresponding values.
  #
  # If a block is given, the results of the block on each pair of
  # the receiver will be used as pairs.
  #
  #   require "ostruct"
  #   data = OpenStruct.new("country" => "Australia", :capital => "Canberra")
  #   data.to_h   # => {:country => "Australia", :capital => "Canberra" }
  #   data.to_h {|name, value| [name.to_s, value.upcase] }
  #               # => {"country" => "AUSTRALIA", "capital" => "CANBERRA" }
  #
  if {test: :to_h}.to_h{ [:works, true] }[:works] # RUBY_VERSION < 2.6 compatibility
    def to_h(&block)
      if block
        instance_variables.to_h do |name|
          key = name.to_s.delete_prefix("@").to_sym

          block.call(key, instance_variable_get(name))
        end
      else
        instance_variables.to_h do |name|
          key = name.to_s.delete_prefix("@").to_sym

          [key, instance_variable_get(name)]
        end
      end
    end
  else
    def to_h(&block)
      if block
        instance_variables
          .map do |name|
            key = name.to_s.delete_prefix("@").to_sym

            [key, instance_variable_get(name)]
          end
          .to_h
      else
        instance_variables.to_h do |name|
          key = name.to_s.delete_prefix("@").to_sym

          [key, instance_variable_get(name)]
        end
      end
    end
  end

  #
  # :call-seq:
  #   ostruct.each_pair {|name, value| block }  -> ostruct
  #   ostruct.each_pair                         -> Enumerator
  #
  # Yields all attributes (as symbols) along with the corresponding values
  # or returns an enumerator if no block is given.
  #
  #   require "ostruct"
  #   data = OpenStruct.new("country" => "Australia", :capital => "Canberra")
  #   data.each_pair.to_a   # => [[:country, "Australia"], [:capital, "Canberra"]]
  #
  def each_pair
    # TODO: optimize `instance_variables.size` to avoid array allocation
    return to_enum(__method__) { instance_variables.size } unless defined?(yield)
    # TODO: Optimize #to_h usage
    to_h.each_pair{|p| yield p}
    self
  end

  #
  # Provides marshalling support for use by the Marshal library.
  #
  def marshal_dump # :nodoc:
    to_h
  end

  #
  # Provides marshalling support for use by the Marshal library.
  #
  alias_method :marshal_load, :update_to_values! # :nodoc:

  #
  # Used internally to defined properties on the
  # OpenStruct. It does this by using the metaprogramming function
  # define_singleton_method for both the getter method and the setter method.
  #
  def new_ostruct_member!(name) # :nodoc:
    ivar_name = :"@#{name}"

    unless instance_variable_defined?(ivar_name) || is_method_protected!(name)
      # if defined?(::Ractor)
      #   getter_proc = nil.instance_eval{ Proc.new { @table[name] } }
      #   setter_proc = nil.instance_eval{ Proc.new {|x| @table[name] = x} }
      #   ::Ractor.make_shareable(getter_proc)
      #   ::Ractor.make_shareable(setter_proc)
      # else
      #   getter_proc = Proc.new { @table[name] }
      #   setter_proc = Proc.new {|x| @table[name] = x}
      # end
      # define_singleton_method!(name, &getter_proc)
      # define_singleton_method!("#{name}=", &setter_proc)

      # TODO: Optimization opportunity. Call `attr_accessor` once with multiple names, and the looping will be done in C
      singleton_class.attr_accessor(name)
    end
  end
  private :new_ostruct_member!

  private def is_method_protected!(name) # :nodoc:
    if !respond_to?(name, true)
      false
    elsif name.match?(/!$/)
      true
    else
      owner = method!(name).owner
      if owner.class == ::Class
        owner < ::OpenStruct
      else
        self.class!.ancestors.any? do |mod|
          return false if mod == ::OpenStruct
          mod == owner
        end
      end
    end
  end

  private def method_missing(mid, *args) # :nodoc:
    len = args.length
    if mname = mid[/.*(?==\z)/m]
      if len != 1
        raise! ArgumentError, "wrong number of arguments (given #{len}, expected 1)", caller(1)
      end
      set_ostruct_member_value!(mname, args[0])
    elsif len == 0
      instance_variable_get(:"@#{mid}")
    else
      begin
        super
      rescue NoMethodError => err
        err.backtrace.shift
        raise!
      end
    end
  end

  #
  # :call-seq:
  #   ostruct[name]  -> object
  #
  # Returns the value of an attribute, or +nil+ if there is no such attribute.
  #
  #   require "ostruct"
  #   person = OpenStruct.new("name" => "John Smith", "age" => 70)
  #   person[:age]   # => 70, same as person.age
  #
  def [](name)
    # name = name.to_sym
    #
    # # # TODO: temporary hack. Is there a reliable way to encode into a valid ivar identifier?
    # # name = +(name.to_s)
    # # name.gsub!("?", "__q_q__")
    # # name.gsub!("!", "__e_p__")
    #
    # instance_variable_get(:"@#{name}")

    # Testing: is `#send` faster than `instance_variable_get`? It doesn't need any string manipularion on `name
    send(name)
  end

  #
  # :call-seq:
  #   ostruct[name] = obj  -> obj
  #
  # Sets the value of an attribute.
  #
  #   require "ostruct"
  #   person = OpenStruct.new("name" => "John Smith", "age" => 70)
  #   person[:age] = 42   # equivalent to person.age = 42
  #   person.age          # => 42
  #
  def []=(name, value)
    # name = name.to_sym

    # # TODO: temporary hack. Is there a reliable way to encode into a valid ivar identifier?
    # name = +(name.to_s)
    # name.gsub!("?", "__q_q__")
    # name.gsub!("!", "__e_p__")

    new_ostruct_member!(name)
    # instance_variable_set(:"@#{name}", value) # TODO: is it worth reusing the symbol with `new_ostruct_member!`?
    send("#{name}=", value) # Testing: is `#send` faster than `instance_variable_set`?
  end
  alias_method :set_ostruct_member_value!, :[]=
  private :set_ostruct_member_value!

  # :call-seq:
  #   ostruct.dig(name, *identifiers) -> object
  #
  # Finds and returns the object in nested objects
  # that is specified by +name+ and +identifiers+.
  # The nested objects may be instances of various classes.
  # See {Dig Methods}[rdoc-ref:dig_methods.rdoc].
  #
  # Examples:
  #   require "ostruct"
  #   address = OpenStruct.new("city" => "Anytown NC", "zip" => 12345)
  #   person  = OpenStruct.new("name" => "John Smith", "address" => address)
  #   person.dig(:address, "zip") # => 12345
  #   person.dig(:business_address, "zip") # => nil
  def dig(name, *names)
    begin
      name = name.to_sym
    rescue NoMethodError
      raise! TypeError, "#{name} is not a symbol nor a string"
    end

    value = self[name]
    return value if names.empty? # Done digging

    return nil unless value.respond_to?(:dig) # TODO: is there a better way to do this?
    value.dig(*names)
  end

  #
  # Removes the named field from the object and returns the value the field
  # contained if it was defined. You may optionally provide a block.
  # If the field is not defined, the result of the block is returned,
  # or a NameError is raised if no block was given.
  #
  #   require "ostruct"
  #
  #   person = OpenStruct.new(name: "John", age: 70, pension: 300)
  #
  #   person.delete_field!("age")  # => 70
  #   person                       # => #<OpenStruct name="John", pension=300>
  #
  # Setting the value to +nil+ will not remove the attribute:
  #
  #   person.pension = nil
  #   person                 # => #<OpenStruct name="John", pension=nil>
  #
  #   person.delete_field('number')  # => NameError
  #
  #   person.delete_field('number') { 8675_309 } # => 8675309
  #
  def delete_field(name, &block)
    sym = name.to_sym
    begin
      singleton_class.remove_method(sym, "#{sym}=")
    rescue NameError
    end

    ivar_name = :"@#{sym}"

    if instance_variable_defined?(ivar_name)
      remove_instance_variable(ivar_name)
    elsif block
      yield
    else
      raise! NameError.new("no field `#{sym}' in #{self}", sym)
    end
  end

  InspectKey = :__inspect_key__ # :nodoc:

  #
  # Returns a string containing a detailed summary of the keys and values.
  #
  def inspect
    ids = (Thread.current[InspectKey] ||= [])
    if ids.include?(object_id)
      detail = ' ...'
    else
      ids << object_id
      begin
        # TODO: worth optimizing out this `#to_h`?
        detail = to_h.map do |key, value|
          " #{key}=#{value.inspect}"
        end.join(',')
      ensure
        ids.pop
      end
    end
    ['#<', self.class!, detail, '>'].join
  end
  alias :to_s :inspect

  attr_reader :table # :nodoc:
  alias table! table
  protected :table!

  #
  # Compares this object and +other+ for equality.  An OpenStruct is equal to
  # +other+ when +other+ is an OpenStruct and the two objects' Hash tables are
  # equal.
  #
  #   require "ostruct"
  #   first_pet  = OpenStruct.new("name" => "Rowdy")
  #   second_pet = OpenStruct.new(:name  => "Rowdy")
  #   third_pet  = OpenStruct.new("name" => "Rowdy", :age => nil)
  #
  #   first_pet == second_pet   # => true
  #   first_pet == third_pet    # => false
  #
  def ==(other)
    return false unless other.kind_of?(OpenStruct)
    # TODO: Implement C extension that uses `obj_ivar_each` and avoids the allocations
    to_h == other.to_h
  end

  #
  # Compares this object and +other+ for equality.  An OpenStruct is eql? to
  # +other+ when +other+ is an OpenStruct and the two objects' Hash tables are
  # eql?.
  #
  def eql?(other)
    return false unless other.kind_of?(OpenStruct)
    # TODO: Implement C extension that uses `obj_ivar_each` and avoids the allocations
    to_h.eql?(other.to_h)
  end

  # Computes a hash code for this OpenStruct.
  def hash # :nodoc:
    # TODO: Implement C extension that uses `obj_ivar_each` and avoids the allocations
    to_h.hash
  end

  #
  # Provides marshalling support for use by the YAML library.
  #
  def encode_with(coder) # :nodoc:
    p instance_variables # Why are these sometimes out of order?
    # Ivar orderings seems to be reliable when I try it in IRB.

    each_pair do |key, value|
      coder[key.to_s] = value
    end

    # TODO: Is this code branch still relevant?
    # TODO: optimize `instance_variables.size` to avoid array allocation
    if instance_variables.size == 1 && instance_variable_defined?(:@table) # support for legacy format
      # in the very unlikely case of a single entry called 'table'
      coder['legacy_support!'] = true # add a bogus second entry
    end
  end

  #
  # Provides marshalling support for use by the YAML library.
  #
  def init_with(coder) # :nodoc:
    h = coder.map
    if h.size == 1 # support for legacy format
      key, val = h.first
      if key == 'table'
        h = val
      end
    end
    update_to_values!(h)
  end

  # Make all public methods (builtin or our own) accessible with <code>!</code>:
  give_access = instance_methods
  # See https://github.com/ruby/ostruct/issues/30
  give_access -= %i[instance_exec instance_eval eval] if RUBY_ENGINE == 'jruby'
  give_access.each do |method|
    next if method.match(/\W$/)

    new_name = "#{method}!"
    alias_method new_name, method
  end
  # Other builtin private methods we use:
  alias_method :raise!, :raise
  private :raise!

  # See https://github.com/ruby/ostruct/issues/40
  if RUBY_ENGINE != 'jruby'
    alias_method :block_given!, :block_given?
    private :block_given!
  end
end
