# frozen_string_literal: true

require "bundler"
Bundler.setup

Dir["./lib/**/*.rb"].each { |f| require f }
