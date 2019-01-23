if ENV['COVERAGE']
  require 'simplecov'

  SimpleCov.start do
    add_filter '/spec/' 
  end
end

require 'bundler'
Bundler.require
require 'rspec'
require 'rubygems'
require File.expand_path(File.dirname(__FILE__) + "/../config/boot")
Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

def group name, *ingress
  {group_name: name, group_id: 'some group', ip_permissions: ingress, ip_permissions_egress: []}
end

def group_ingress port, name
  {user_id_group_pairs:[{user_id: "userId", group_id: "sg-groupId", group_name: name}], ip_ranges:[], ip_protocol: "tcp", from_port: port, to_port: port}
end

def cidr_ingress port, cidr_ip
  {ip_ranges:[{cidr_ip: cidr_ip}], ip_protocol: "tcp", from_port: port, to_port: port}
end

def stub_security_groups groups
  Aws.config[:ec2] = {
    stub_responses: {
        describe_security_groups: {
          security_groups: groups
      }
    }
  }
end