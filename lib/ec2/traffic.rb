class Traffic
  attr_accessor :from, :to, :port_range, :ingress

  def initialize(ingress, from, to, port_range)
    @ingress = ingress
    @from = from
    @to = to
    @port_range = port_range
  end

  def copy(from, to)
    Traffic.new(@ingress, from, to, @port_range)
  end

  def eql?(other)
    @from == other.from && @to == other.to && @port_range == other.port_range
  end

  def hash
    @from.hash + @to.hash + @port_range.hash
  end
end
