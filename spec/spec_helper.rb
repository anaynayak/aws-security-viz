require 'bundler'
Bundler.require

require File.expand_path(File.dirname(__FILE__) + "/../config/boot")

def group name, *ingress
  {
    :aws_owner=>"aws-owner", :aws_group_name=> name, :aws_description=>"Ssh into remote box", :group_id=>"sg-111", 
    :aws_perms=> ingress
  }
end

def ingress port, name
  {:from_port=>port, :to_port=>port, :protocol=>"tcp", :direction=>:ingress, :group_name=>name, :group_id=>"sg-123", :owner=>"own-123"}
end
