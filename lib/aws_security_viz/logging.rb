# frozen_string_literal: true

require "logger"

module AwsSecurityViz
  # Diagnostics (warnings, errors, debug output) go to stderr so stdout stays clean for output.
  def self.logger
    @logger ||= build_logger($stderr)
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.build_logger(io)
    Logger.new(io, formatter: proc { |severity, _time, _prog, msg| "[#{severity}] #{msg}\n" })
  end
end
