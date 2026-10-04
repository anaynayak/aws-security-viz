# frozen_string_literal: true

module AwsSecurityViz
  # Edge labels are comma-joined tokens such as "22/tcp", "1000-2000/udp", "icmp" or "proto 50",
  # or "all" for all traffic.
  module PortLabel
    ALL = "all"
    PROTOCOL_NAMES = {"1" => "icmp", "6" => "tcp", "17" => "udp", "58" => "icmpv6"}.freeze
    ICMP = %w[icmp icmpv6].freeze

    # Protocol of a permission as the viewer's path query names it: "all", "tcp", "udp", "icmp", "icmpv6", or the
    # protocol number as a string.
    def self.protocol(protocol)
      protocol = protocol.to_s
      return ALL if protocol == "-1"
      PROTOCOL_NAMES.fetch(protocol, protocol)
    end

    # Label for one permission. For tcp/udp from/to are ports; for icmp they are the type and code
    # (-1 meaning any); other protocols carry no ports and are shown by name or number.
    def self.format(protocol, from, to)
      protocol = protocol.to_s
      return ALL if protocol == "-1"
      name = PROTOCOL_NAMES.fetch(protocol, protocol)
      return icmp(name, from, to) if ICMP.include?(name)
      return "proto #{name}" if name.match?(/\A\d+\z/)
      return name if from.nil? && to.nil?
      "#{[from, to].uniq.join("-")}/#{name}"
    end

    def self.icmp(name, type, code)
      return name if type.nil? || type == -1
      (code.nil? || code == -1) ? "#{name} #{type}" : "#{name} #{type}/#{code}"
    end
    private_class_method :icmp

    TOKEN = %r{\A(-?\d+)(?:-(-?\d+))?/(.*)\z}

    # Deduplicates tokens and sorts them by from port, then protocol; "all" swallows everything else.
    def self.normalise(label)
      tokens = label.to_s.split(",").uniq
      return ALL if tokens.include?(ALL)
      tokens.sort_by { |token| sort_key(token) }.join(",")
    end

    def self.sort_key(token)
      match = TOKEN.match(token)
      return [1, 0, "", 0, token] unless match
      [0, match[1].to_i, match[3], (match[2] || match[1]).to_i, token]
    end
  end
end
