require 'bundler'
Bundler.require
require 'rspec'
require 'rubygems'

require File.expand_path(File.dirname(__FILE__) + "/../config/boot")
Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

def group name, *ingress
  group = double("Group")
  allow(group).to receive(:ip_permissions).and_return(ingress)
  allow(group).to receive(:name).and_return(name)
  group
end

def group_ingress port, name
  {"groups"=>[{"userId"=>"userId", "groupId"=>"sg-groupId", "groupName"=>name}], "ipRanges"=>[], "ipProtocol"=>"tcp", "fromPort"=>port, "toPort"=>port}
end

def cidr_ingress port, cidr_ip
  {"groups"=>[], "ipRanges"=>[{"cidrIp"=> cidr_ip}], "ipProtocol"=>"tcp", "fromPort"=>port, "toPort"=>port}
end
