# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "run standardrb"
task :standard do
  sh "bundle exec standardrb"
end

task default: [:standard, :spec]

namespace :docker do
  task :login do
    sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin'
  end
  desc "push to dockerhub"
  task push: :login do
    sh "docker build -t anay/aws-security-viz ."
    sh "docker push anay/aws-security-viz"
  end
end
