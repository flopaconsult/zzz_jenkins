#
# Cookbook Name:: jenkins
# Based on hudson
# Recipe:: remote
#
# Author:: Valeriu Craciun <craciun_val@yahoo.com>
#
# Include this recipe for all hosts which want to be found by jenkins.
# If many jenkins servers will be on the same environment, then the first one will be considered only.
#

node.set[:jenkins][:remote] = true

jenkins_server_nodes = search(:node, "jenkins_server_server:true AND app_environment:#{node[:app_environment]}")
if jenkins_server_nodes.empty?
  Chef::Log.warn("No jenkins server returned from search. Please start jenkins server first.")
  node.set[:jenkins][:server][:host] = ""
  node.set[:jenkins][:server][:pubkey] = ""
else
  jenkins_server_node = jenkins_server_nodes.first
  node.set[:jenkins][:server][:host] = jenkins_server_node[:jenkins][:server][:host]
  node.set[:jenkins][:server][:pubkey] = jenkins_server_node[:jenkins][:server][:pubkey]
  Chef::Log.info("Jenkins server node is: #{jenkins_server_node[:ipaddress]}")
end

