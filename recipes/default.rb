#
# Cookbook Name:: jenkins
# Based on hudson
# Recipe:: default
#
# Author:: AJ Christensen <aj@junglist.gen.nz>
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

Chef::Log.info("!!!!! #{node[:tags]}")
pkey = "#{node[:jenkins][:server][:home]}/.ssh/id_rsa"
tmp = "/tmp"

#!!!!!! USER ALREADY CREATED IN CHEF-WORKSPACE COOKBOOK !!!!!!!!!
#!!!!!! IF NOT USED IN CONJUNCTION WITH CHEF WORKSPACE THEN USE THE OPSCODE DEFAULT RECIPE !!!!!!!

# add jenkins user to sudoers

node.default.authorization.sudo.users << "ubuntu"
node.default.authorization.sudo.groups << "ubuntu"
node.default.authorization.sudo.users << node[:jenkins][:server][:user]
node.default.authorization.sudo.groups << node[:jenkins][:server][:group]
#node[:authorization][:sudo][:users] << node[:jenkins][:server][:user]
#node[:authorization][:sudo][:groups] << node[:jenkins][:server][:group]

include_recipe "sudo"

ruby_block "store jenkins ssh pubkey" do
  block do
    file = File.open("#{pkey}", "rb")
    contents = file.read
    node.set[:jenkins][:server][:pubkey] = contents
    file.close
    #node.set[:jenkins][:server][:pubkey] = File.open("#{pkey}") { |f| f.gets }
  end
end

directory "#{node[:jenkins][:server][:home]}/plugins" do
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
  only_if { node[:jenkins][:server][:plugins].size > 0 }
end

node[:jenkins][:server][:plugins].each do |name|
  remote_file "#{node[:jenkins][:server][:home]}/plugins/#{name}.hpi" do
    source "#{node[:jenkins][:mirror]}/plugins/#{name}/latest/#{name}.hpi"
    backup false
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
    action :create_if_missing
  end
end

#include git-core install if git plugin is installed
if node[:jenkins][:server][:plugins].include?("git")
  Chef::Log.info "include GIT recipe"
  include_recipe "git"
end

case node.platform
when "ubuntu", "debian"
  include_recipe "apt"
  include_recipe "java"

  pid_file = "/var/run/jenkins/jenkins.pid"
  install_starts_service = true

  apt_repository "jenkins" do
    uri "#{node.jenkins.package_url}/debian"
    components %w[binary/]
    key "http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key"
    action :add
  end
when "centos", "redhat"
  include_recipe "yum"

  pid_file = "/var/run/jenkins.pid"
  install_starts_service = false

  yum_key "jenkins" do
    url "#{node.jenkins.package_url}/redhat/jenkins-ci.org.key"
    action :add
  end

  yum_repository "jenkins" do
    description "repository for jenkins"
    url "#{node.jenkins.package_url}/redhat/"
    key "jenkins"
    action :add
  end
end

#"jenkins stop" may (likely) exit before the process is actually dead
#so we sleep until nothing is listening on jenkins.server.port (according to netstat)
ruby_block "netstat" do
  block do
    100.times do
      if IO.popen("netstat -lnt").entries.select { |entry|
          entry.split[3] =~ /:#{node[:jenkins][:server][:port]}$/
        }.size == 0
        break
      end
      Chef::Log.info("service[jenkins] still listening (port #{node[:jenkins][:server][:port]})")
      sleep 3
    end
  end
  action :nothing
end

service "jenkins" do
  service_name "jenkins"
  supports [ :stop, :start, :restart, :status, :reload ]
  status_command "test -f #{pid_file} && kill -0 `cat #{pid_file}`"
  reload_command "sudo /etc/init.d/jenkins force-reload"
  action :nothing
end

ruby_block "block_until_operational" do
  block do
    Chef::Log.info "Waiting for Jenkins server to start..."
    until IO.popen("netstat -lnt").entries.select { |entry|
        entry.split[3] =~ /:#{node[:jenkins][:server][:port]}$/
      }.size == 1
      Chef::Log.info "service[jenkins] not listening on port #{node.jenkins.server.port}"
      sleep 5
    end

    loop do
      url = URI.parse("#{node.jenkins.server.url}/job/test/config.xml")
      res = Chef::REST::RESTRequest.new(:GET, url, nil).call
      break if res.kind_of?(Net::HTTPSuccess) or res.kind_of?(Net::HTTPNotFound)
      Chef::Log.debug "service[jenkins] not responding OK to GET / #{res.inspect}"
      sleep 5
    end
    Chef::Log.info "Jenkins server is operational."
  end
  action :nothing
end

log "jenkins: install and start" do
  notifies :install, "package[jenkins]", :immediately
  notifies :start, "service[jenkins]", :immediately unless install_starts_service
  notifies :create, "ruby_block[block_until_operational]", :immediately
  not_if do
    File.exists? "/usr/share/jenkins/jenkins.war"
  end
end

template "/etc/default/jenkins"

package "jenkins" do
  action :nothing
  notifies :create, "template[/etc/default/jenkins]", :immediately
end

# restart if this run only added new plugins
log "plugins updated, restarting jenkins" do
  #ugh :restart does not work, need to sleep after stop.
  notifies :stop, "service[jenkins]", :immediately
  notifies :create, "ruby_block[netstat]", :immediately
  notifies :start, "service[jenkins]", :immediately
  notifies :create, "ruby_block[block_until_operational]", :immediately
  only_if do
    if File.exists?(pid_file)
      htime = File.mtime(pid_file)
      Dir["#{node[:jenkins][:server][:home]}/plugins/*.hpi"].select { |file|
        File.mtime(file) > htime
      }.size > 0
    end
  end

  action :nothing
end

# Front Jenkins with an HTTP server
case node[:jenkins][:http_proxy][:variant]
when "nginx"
  include_recipe "jenkins::proxy_nginx"
when "apache2"
  include_recipe "jenkins::proxy_apache2"
end

if node.jenkins.iptables_allow == "enable"
  include_recipe "iptables"
  iptables_rule "port_jenkins" do
    if node[:jenkins][:iptables_allow] == "enable"
      enable true
    else
      enable false
    end
  end
end


# Link ruby into /usr/bin/ruby, to allow /usr/bin/env 
# TODO - remove it to a more common recipe
bash "Link ruby and gem" do
  code <<-EOH
	if [ ! -f /usr/bin/ruby ]
	then
		sudo ln -s /opt/chef/embedded/bin/ruby /usr/bin/ruby
	fi
	if [ ! -f /usr/bin/gem ]
	then
		sudo ln -s /opt/chef/embedded/bin/gem /usr/bin/gem
	fi
  EOH
end


# Create scripts directory
directory node[:jenkins][:server][:scripts_dir] do
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
end


# Jenkins main config
template "Jenkins main config" do
  source "jenkins_config.xml.erb"
  path "#{node[:jenkins][:server][:home]}/config.xml"
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
  mode "0644"
  variables(
    :DEFAULT_VIEWS => node[:jenkins][:views]
  )
end


# SSH sites template
template "Update SSH sites run list" do
  source "update_ssh_sites.json.erb"
  path "#{node[:jenkins][:server][:scripts_dir]}/update_ssh_sites.json"
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
  mode "0644"
end

# make a initial call in order to prepare cli (usually this is called on first call of a job resource, 
# but it is better to have it prepared)
# this will download jenkins-cli.jar to the jenkins home directory
jenkins_cli "Download and prepare jenkins command line tools" do
  action :run
  command "version"
end

node.set[:jenkins][:server][:server] = true

log "Restart jenkins again for reloading config" do  
  notifies :restart, "service[jenkins]", :immediately
  notifies :create, "ruby_block[block_until_operational]", :immediately
end



