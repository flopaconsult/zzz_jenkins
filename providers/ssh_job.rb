#
# Cookbook Name:: jenkins
# Based on hudson
# Provider:: remote_host_config
#
# Author:: Valeriu Craciun
#


def action_create
  job_name = "#{@new_resource.job_name}"
  remote_host = "#{@new_resource.remote_host}"
  job_config = "#{node[:jenkins][:server][:home]}/#{@new_resource.job_name}-config.xml"
  
  run_commands = Array.new
  to_store_scripts = Array.new
  
  @new_resource.commands.each do |command|
    if (command[:type] == 'script')
	  to_store_scripts << "#{command[:content]}"
	  command[:fullPath] = "#{node[:jenkins][:node][:home]}/jenkins-scripts/#{command[:content]}"
	else
	   command[:fullPath] = "#{command[:content]}"
	end
  
    if (command[:type] == 'script' && command[:action] == 'run') || command[:type] == 'command'
      run_commands << command
    end
  end

  template job_config do
    source "#{new_resource.config_template}"
    variables :job_name => job_name, :remote_host => remote_host, :commands => run_commands
	owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
  end
  
  
  # Create sh files and upload them to remote host
  to_store_scripts.each do |script|
  
    # create scripts on jenkins server
    cookbook_file "#{node[:jenkins][:server][:home]}/jenkins-scripts/#{script}" do
      source "#{script}"
      owner node[:jenkins][:server][:user]
      group node[:jenkins][:server][:group]
      action :create
	  mode "0755"
    end
  
    #upload scripts to host only if host is reachable
	bash "upload script #{script} on server #{remote_host}" do
      user node[:jenkins][:server][:user]
      cwd "#{node[:jenkins][:server][:home]}/jenkins-scripts/"
	  code <<-EOH
scp #{script} #{node[:jenkins][:node][:user]}@#{remote_host}:#{node[:jenkins][:node][:home]}/jenkins-scripts
ssh #{node[:jenkins][:node][:user]}@#{remote_host} chmod 755 #{node[:jenkins][:node][:home]}/jenkins-scripts/*
EOH
      only_if "ping -q -c1 #{remote_host}"
    end
  end

  jenkins_job "#{@new_resource.job_name}" do
    action :update
    config job_config
  end  
  
  file job_config do
    action :delete
	backup false
  end
end