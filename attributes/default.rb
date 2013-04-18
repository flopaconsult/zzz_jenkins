#
# Cookbook Name:: jenkins
# Based on hudson
# Attributes:: default
#
# Author:: Doug MacEachern <dougm@vmware.com>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
#
# Copyright 2010, VMware, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default[:jenkins][:job_name_checkout] = "GIT-checkout"
default[:jenkins][:git][:repo] = "git@github.com:fdrescher/magento.git"

default[:jenkins][:mirror] = "http://mirrors.jenkins-ci.org"
default[:jenkins][:package_url] = "http://pkg.jenkins-ci.org"
default[:jenkins][:java_home] = ENV['JAVA_HOME']

default[:jenkins][:server][:home] = "/var/chef-workspace"
default[:jenkins][:server][:user] = "chef-workspace"
default[:jenkins][:server][:scripts_dir] = "#{node[:jenkins][:server][:home]}/jenkins-scripts"

#case node[:platform]
#when "debian", "ubuntu"
#  default[:jenkins][:server][:group] = "nogroup"
#else
  default[:jenkins][:server][:group] = node[:jenkins][:server][:user]
#end

default[:jenkins][:server][:port] = 8080
default[:jenkins][:server][:host] = node[:fqdn]
default[:jenkins][:server][:url]  = "http://#{node[:ipaddress]}:#{node[:jenkins][:server][:port]}"

default[:jenkins][:iptables_allow] = "disable"

#download the latest version of plugins, bypassing update center
#example: ["git", "URLSCM", ...]
default[:jenkins][:server][:plugins] = ["ssh", "git", "github", "github-api", "saferestart", "envinject", 
                                        "view-job-filters", "dashboard-view", "compact-columns", 
                                        "countjobs-viewstabbar", "project-stats-plugin", "ruby", 
                                        "jenkins-multijob-plugin", "validating-string-parameter", "dynamicparameter",
                                        "extended-choice-parameter", "extensible-choice-parameter", "scriptler",
										"show-build-parameters", "publish-over-ssh"]

#working around: http://tickets.opscode.com/browse/CHEF-1848
#set to true if you have the CHEF-1848 patch applied
default[:jenkins][:server][:use_head] = false

#See Jenkins >> Nodes >> $name >> Configure

#"Name"
default[:jenkins][:node][:name] = node[:fqdn]

#"Description"
default[:jenkins][:node][:description] =
  "#{node[:platform]} #{node[:platform_version]} " <<
  "[#{node[:kernel][:os]} #{node[:kernel][:release]} #{node[:kernel][:machine]}] " <<
  "slave on #{node[:hostname]}"

#"# of executors"
default[:jenkins][:node][:executors] = 1

#"Remote FS root"
if node[:os] == "windows"
  default[:jenkins][:node][:home] = "C:/jenkins"
elsif node[:os] == "darwin"
  default[:jenkins][:node][:home] = "/Users/jenkins"
else
  default[:jenkins][:node][:home] = node[:jenkins][:server][:home]
end

#"Labels"
default[:jenkins][:node][:labels] = (node[:tags] || []).join(" ")

#"Usage"
#  "Utilize this slave as much as possible" -> "normal"
#  "Leave this machine for tied jobs only"  -> "exclusive"
default[:jenkins][:node][:mode] = "normal"

#"Launch method"
#  "Launch slave agents via JNLP"                        -> "jnlp"
#  "Launch slave via execution of command on the Master" -> "command"
#  "Launch slave agents on Unix machines via SSH"         -> "ssh"
if node[:os] == "windows"
  default[:jenkins][:node][:launcher] = "jnlp"
else
  default[:jenkins][:node][:launcher] = "ssh"
end

#"Availability"
#  "Keep this slave on-line as much as possible"                   -> "always"
#  "Take this slave on-line when in demand and off-line when idle" -> "demand"
default[:jenkins][:node][:availability] = "always"

#  "In demand delay"
default[:jenkins][:node][:in_demand_delay] = 0
#  "Idle delay"
default[:jenkins][:node][:idle_delay] = 1

#"Node Properties"
#[x] "Environment Variables"
default[:jenkins][:node][:env] = nil

#default[:jenkins][:node][:user] = "jenkins-node"
default[:jenkins][:node][:user] = "ubuntu"

#SSH options
default[:jenkins][:node][:ssh_host] = node[:fqdn]
default[:jenkins][:node][:ssh_port] = 22
default[:jenkins][:node][:ssh_user] = default[:jenkins][:node][:user]
default[:jenkins][:node][:ssh_pass] = nil
default[:jenkins][:node][:jvm_options] = nil
#jenkins master defaults to: "#{ENV['HOME']}/.ssh/id_rsa"
default[:jenkins][:node][:ssh_private_key] = nil

default[:jenkins][:http_proxy][:variant]              = "apache2"
default[:jenkins][:http_proxy][:www_redirect]         = "disable"
default[:jenkins][:http_proxy][:listen_ports]         = [ 80 ]
default[:jenkins][:http_proxy][:host_name]            = nil
default[:jenkins][:http_proxy][:host_aliases]         = []
default[:jenkins][:http_proxy][:client_max_body_size] = "1024m"
default[:jenkins][:http_proxy][:basic_auth_username] = "jenkins"
default[:jenkins][:http_proxy][:basic_auth_password] = "jenkins"

default[:jenkins][:server_role] = "chef-workspace"
default[:jenkins][:remote_ssh_role] = "jenkins_remote"

default[:ssh_commands] = {
  :all_servers => [
    {:type => 'script', :content => 'run-chef-client-remote.sh', :action => 'run'},
	{:type => 'command', :content => 'sudo apt-get install mc -y', :action => 'run'},
	{:type => 'script', :content => 'store.sh', :action => 'store'}
  ]
}


default[:jenkins][:views] = [
  {:name => 'REMOTE SSH', :filters => [{:type => 'includeMatched', :valueType => 'NAME', :regexp => 'remote-SSH.*'}]}
]
default[:jenkins][:jobs][:subnets] = ["subnet-963364fd", "subnet-e60e598d", "subnet-d53166be"]
default[:jenkins][:jobs][:regions] = ["us-east-1","us-west-1","us-west-2","eu-west-1","sa-east-1","ap-northeast-1","ap-southeast-1","ap-southeast-2"]
default[:jenkins][:jobs][:availabilityzones] = ["us-east-1e","us-east-1d","us-east-1c","us-east-1b","us-east-1a",
                                                "us-west-1a","us-west-1b","us-west-1c",
                                                "us-west-2a","us-west-2b","us-west-2c",
                                                "eu-west-1a","eu-west-1b","eu-west-1c",
                                                "sa-east-1a","sa-east-1b",
                                                "ap-northeast-1a","ap-northeast-1b","ap-northeast-1c",
                                                "ap-southeast-1a","ap-southeast-1b",
                                                "ap-southeast-2a","ap-southeast-2b"]
