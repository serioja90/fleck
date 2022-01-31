# frozen_string_literal: true

# `HashWithIndifferentAccess` extends `Hash` class and adds the possibility to access values
# by using both string and symbol keys indifferently.
class HashWithIndifferentAccess < Hash
  def initialize(original)
    super(nil)
    copy_from(original)
  end

  def []=(key, value)
    super(key.to_s, self.class.convert_value(value))
  end

  def [](key)
    super(key.to_s)
  end

  def fetch(key, *extras)
    super(key.to_s, *extras)
  end

  def delete(key)
    super(key.to_s)
  end

  def self.convert_value(value)
    case value
    when Hash
      value.to_hash_with_indifferent_access
    when Array
      value.map! { |item| item.is_a?(Hash) || item.is_a?(Array) ? HashWithIndifferentAccess.convert_value(item) : item }
    else
      value
    end
  end

  protected

  def copy_from(original)
    original.each do |key, value|
      self[key] = self.class.convert_value(value)
    end
  end
end

# Open `Hash` class to add `#to_hash_with_indifferent_access` method and some filter features.
class Hash
  def to_hash_with_indifferent_access
    HashWithIndifferentAccess.new(self)
  end

  def to_s
    return dup.filter!.inspect if @filtered

    super
  end

  def filtered!
    @filtered = true
    keys.each do |key|
      self[key].filtered! if self[key].is_a?(Hash)
    end

    self
  end

  def filter!
    filters = Fleck.config.filters
    keys.each do |key|
      if filters.include?(key.to_s)
        self[key] = '[FILTERED]'
      elsif self[key].is_a?(Hash)
        self[key] = self[key].dup.filter!
      end
    end

    self
  end
end
