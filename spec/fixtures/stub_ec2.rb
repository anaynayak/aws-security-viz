# frozen_string_literal: true

# Loaded with `ruby -r` into an exe subprocess: stubs EC2 and reports the options the client was built with.
require "aws-sdk-ec2"

Aws.config[:ec2] = {stub_responses: true}

Aws::EC2::Client.prepend(Module.new {
  def initialize(*args)
    super
    # Hash#inspect changed format in Ruby 3.4, so print the options in one fixed form.
    options = args.last.sort.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
    warn "CLIENT {#{options}} region=#{config.region}"
  end
})
