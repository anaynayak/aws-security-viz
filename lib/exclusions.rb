class Exclusions
  attr_reader :patterns

  def initialize(patterns)
    @patterns = patterns.map {|p| /#{p}/} unless patterns.nil?
  end

  def match(str)
    return false if patterns.nil?
    patterns.any? { |p|
      p.match(str)
    }
  end
end
