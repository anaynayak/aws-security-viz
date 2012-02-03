require 'bundler'
Bundler.setup

Dir["./lib/**/*.rb"].each { |f| require f }
