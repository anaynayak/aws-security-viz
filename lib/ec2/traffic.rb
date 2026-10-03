# frozen_string_literal: true

require_relative "../port_label"

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
    if @ingress == other.ingress
      @from == other.from && @to == other.to && @port_range == other.port_range
    else
      @from == other.to && @to == other.from && @port_range == other.port_range
    end
  end

  def hash
    @from.hash + @to.hash + @port_range.hash # standard:disable Security/CompoundHash (order-insensitive, matches eql?)
  end

  def self.grouped(traffic_list)
    t = traffic_list.first
    port_range = traffic_list.collect(&:port_range).join(",")
    port_range = PortLabel.normalise(port_range)
    Traffic.new(t.ingress, t.from, t.to, port_range)
  end
end
