class ColorPicker
  def initialize(colored)
    @picker = colored ? NodeColors.new : DefaultColors.new
  end
  def color(index, ingress)
    @picker.color(index, ingress)
  end
  class NodeColors
    def color(index, ingress)
      GraphViz::Utils::Colors::COLORS.keys[index]
    end
  end
  class DefaultColors
    def color(index, ingress)
      ingress ? :blue : :red
    end
  end
end
