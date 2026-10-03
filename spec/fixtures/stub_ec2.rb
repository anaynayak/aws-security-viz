# frozen_string_literal: true

# Loaded with `ruby -r` into an exe subprocess: stubs EC2 and reports the options the client was built with.
require "aws-sdk-ec2"

Aws.config[:ec2] = {stub_responses: true}

Aws::EC2::Client.prepend(Module.new {
  def initialize(*args)
    super
    warn "CLIENT #{args.last.inspect} region=#{config.region}"
  end
})
