#
# Cookbook Name:: jenkins
# Based on hudson
# Resource:: server.rb
#
# Author:: Valeriu Craciun
#

actions :srestart, :reloadconfig

attribute :url, :kind_of => String

def initialize(name, run_context=nil)
  super
  @action = :srestart
  @url = node[:jenkins][:server][:url]
end