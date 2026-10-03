# frozen_string_literal: true

require "json"
require_relative "../model"

module AwsSecurityViz
  class JsonProvider
    def initialize(options)
      @groups = Model.normalize(JSON.parse(File.read(options[:source_file]))["SecurityGroups"])
      @groups = @groups.select { |sg| sg[:vpc_id] == options[:vpc_id] } if options[:vpc_id]
    end

    def security_groups
      Model.resolve_peer_names(@groups.map { |sg| SecurityGroup.from_hash(sg) })
    end
  end
end
