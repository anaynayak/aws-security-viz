# frozen_string_literal: true

require "aws-sdk-ec2"

# Runs the CLI body and turns failures into a message and an exit status:
# 0 on success, 130 on Ctrl-C (quietly), 1 on any other error. `debug` (a flag or a callable)
# re-raises after printing so the backtrace is visible.
module CliGuard
  INTERRUPTED = 130

  def self.run(debug: false, out: $stdout)
    yield
    0
  rescue Interrupt
    INTERRUPTED
  rescue => e
    out.puts "[ERROR] #{message(e)}"
    raise e if debug.respond_to?(:call) ? debug.call : debug
    1
  end

  def self.message(error)
    case error
    when Aws::Errors::MissingRegionError
      "no AWS region; pass -r/--region or set AWS_REGION (or use a profile with a region)"
    when Aws::Errors::MissingCredentialsError
      "no AWS credentials found; pass -a/-s, set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, or use --profile"
    when Aws::Errors::ServiceError
      "AWS #{error.class.name.split("::").last}: #{error.message}"
    when Seahorse::Client::NetworkingError
      "could not reach AWS: #{error.message}"
    else
      error.message
    end
  end
end
