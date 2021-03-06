
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
    if value.is_a?(Hash)
      value.to_hash_with_indifferent_access
    elsif value.is_a?(Array)
      value.map!{|item| item.is_a?(Hash) || item.is_a?(Array) ? HashWithIndifferentAccess.convert_value(item) : item }
    else
      value
    end
  end

  def inspect
    super
  end

  def to_s
    super
  end

  protected

  def copy_from(original)
    original.each do |key, value|
      self[key] = self.class.convert_value(value)
    end
  end
end


class Hash
  def to_hash_with_indifferent_access
    return HashWithIndifferentAccess.new(self)
  end

  def to_s
    if @filtered
      return self.dup.filter!.inspect
    else
      super
    end
  end

  def filtered!
    @filtered = true
    self.keys.each do |key|
      self[key].filtered! if self[key].is_a?(Hash)
    end
    return self
  end

  def filter!
    filters = Fleck.config.filters
    self.keys.each do |key|
      if filters.include?(key.to_s)
        self[key] = "[FILTERED]"
      elsif self[key].is_a?(Hash)
        self[key] = self[key].dup.filter!
      end
    end

    return self
  end
end