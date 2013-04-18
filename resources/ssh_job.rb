#
# Cookbook Name:: jenkins
# Based on hudson
# Resource:: remote_host_config
#
# Author:: Valeriu Craciun
#

actions :create

attribute :url, :kind_of => String
attribute :description, :kind_of => String
attribute :job_name, :kind_of => String
attribute :config_template, :kind_of => String
attribute :remote_host, :kind_of => String
attribute :commands, :kind_of => Array, :default => []


def initialize(name, run_context=nil)
  super
  @action = :update
  @job_name = name
  @url = node[:jenkins][:server][:url]
end