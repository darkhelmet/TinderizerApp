class Object
  def or_else(*args, &block)
    self
  end
end

class Nothing
  def method_missing(*args, &block)
    self
  end

  def nil?; true; end
  alias :blank? :nil?
  alias :empty? :nil?

  def present?; false; end
  def to_s; ''; end

  def or_else(other = nil)
    block_given? ? yield : other
  end
end

module Kernel
  def Maybe(value)
    value.nil? ? Nothing.new : value
  end
end
