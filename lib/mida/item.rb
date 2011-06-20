require 'nokogiri'
require_relative '../mida'
require_relative 'datatypes'
require_relative 'itemscope'
require_relative 'vocabulary'

module Mida

  # Class that holds a validated item
  class Item

    # The vocabulary used to interpret this item
    attr_reader :vocabulary

    # The Type of the item
    attr_reader :type

    # The Global Identifier of the item
    attr_reader :id

    # A Hash representing the properties as name/values paris
    # The values will be an array containing either +String+
    # or <tt>Mida::Item</tt> instances
    attr_reader :properties

    # Create a new Item object from an +Itemscope+ and validates
    # its +properties+
    #
    # [itemscope] The itemscope that has been parsed by +Itemscope+
    def initialize(itemscope)
      @type = itemscope.type
      @id = itemscope.id
      @vocabulary = Mida::Vocabulary.find(@type)
      @properties = itemscope.properties
      validate_properties
    end

    # Return a Hash representation
    # of the form:
    #   { vocabulary: 'http://example.com/vocab/review',
    #     type: 'The item type',
    #     id: 'urn:isbn:1-934356-08-5',
    #     properties: {'a name' => 'avalue' }
    #   }
    def to_h
      {vocabulary: @vocabulary, type: @type, id: @id, properties: properties_to_h(@properties)}
    end

    def to_s
      to_h.to_s
    end

    def ==(other)
      @vocabulary == other.vocabulary && @type == other.type &&
      @id == other.id && @properties == other.properties
    end

  private

    # Validate the properties so that they are in their proper form
    def validate_properties
      @properties =
      @properties.each_with_object({}) do |(property, values), hash|
        if valid_property?(property, values)
          hash[property] = validate_values(property, values)
        end
      end
    end

    # Return whether the number of values conforms to the spec
    def valid_num_values?(property, values)
      return false unless @vocabulary.prop_spec.has_key?(property)
      property_spec = @vocabulary.prop_spec[property]
      (property_spec[:num] == :many ||
        (property_spec[:num] == :one && values.length == 1))
    end

    def valid_property?(property, values)
      [property, :any].any? {|prop| valid_num_values?(prop, values)}
    end

    # Return valid values, converted to the correct +DataType+ if necessary
    def validate_values(property, values)
      prop_types = if @vocabulary.prop_spec.has_key?(property)
        @vocabulary.prop_spec[property][:types]
      else
        @vocabulary.prop_spec[:any][:types]
      end

      valid_values = []
      values.each do |value|
        value = Item.new(value) if is_itemscope?(value)
        if (type = valid_type?(prop_types, value))
          if DataTypes::TYPES.include?(type)
            DataTypes.extract(type, value)
          end
          valid_values << value
        end
      end
      valid_values
    end

    def is_itemscope?(object)
      object.kind_of?(Itemscope)
    end

    def is_item?(object)
      object.respond_to?(:vocabulary)
    end

    # Returns the valid type of the +value+ or +nil+ if not valid
    def valid_type?(valid_types, value)
      if is_item?(value)
        if valid_types.include?(value.vocabulary) || valid_types.include?(:any)
          return value.vocabulary
        end
      elsif (type = valid_types.find {|type| DataTypes.valid?(type, value)})
        return type
      elsif valid_types.include?(:any)
        return :any
      end
      nil
    end

    # The value as it should appear in to_h()
    def value_to_h(value)
      case
      when value.is_a?(Array) then value.collect {|element| value_to_h(element)}
      when value.is_a?(Item) then value.to_h
      else value
      end
    end

    def properties_to_h(properties)
      properties.each_with_object({}) do |(name, value), hash|
        hash[name] = value_to_h(value)
      end
    end

  end

end
