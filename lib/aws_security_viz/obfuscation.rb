# frozen_string_literal: true

require "digest"

module AwsSecurityViz
  # Replaces names, ids and port labels with short stable hashes. It runs on the finished
  # graph (after merging and filtering), so filters still match real names and ids and
  # merged edges keep deduplicated, hashed port tokens.
  module Obfuscation
    LENGTH = 10

    def self.apply(nodes, edges)
      [
        nodes.map { |key, opts| [hash(key), node_opts(opts)] },
        edges.map { |from, to, opts| [hash(from), hash(to), opts.merge(label: hash_tokens(opts[:label]))] }
      ]
    end

    def self.node_opts(opts)
      %i[label vpc_id group_id].each_with_object(opts.dup) { |field, hashed|
        hashed[field] = hash(opts[field]) if opts.key?(field) && !opts[field].nil?
      }
    end

    # Hash each comma-separated port token so that one token always maps to the same value.
    def self.hash_tokens(label)
      label.to_s.split(",").map { |token| hash(token) }.join(",")
    end

    def self.hash(text)
      Digest::SHA256.hexdigest(text.to_s)[0, LENGTH]
    end
  end
end
