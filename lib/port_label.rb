# frozen_string_literal: true

# Edge labels are comma-joined port tokens such as "22/tcp" or "1000-2000/udp", or "*" for all traffic.
module PortLabel
  TOKEN = %r{\A(-?\d+)(?:-(-?\d+))?/(.*)\z}

  # Deduplicates tokens and sorts them by from port, then protocol; "*" swallows everything else.
  # `wildcard` is the all-traffic token (a hash when labels are obfuscated).
  def self.normalise(label, wildcard: "*")
    tokens = label.to_s.split(",").uniq
    return wildcard if tokens.include?(wildcard)
    tokens.sort_by { |token| sort_key(token) }.join(",")
  end

  def self.sort_key(token)
    match = TOKEN.match(token)
    return [1, 0, "", 0, token] unless match
    [0, match[1].to_i, match[3], (match[2] || match[1]).to_i, token]
  end
end
