#node.set[:jenkins][:server][:enabled_remote_hosts] = nil #for test only to clean attribute

#search all hosts in current environment where need to run commands over ssh
if node[:jenkins][:server][:enabled_remote_hosts].nil? || node[:jenkins][:server][:enabled_remote_hosts].empty?
  node.set[:jenkins][:server][:enabled_remote_hosts] = Array.new 
end
  
jenkins_ssh_nodes = search(:node, "jenkins_remote:true AND app_environment:#{node[:app_environment]}")
ssh_sites_result = Array.new
ssh_sites_as_web_servers = Array.new
jenkins_ssh_nodes.each do |n|
  if n.has_key?("jenkins") && n.jenkins.has_key?("elb")
    server_fqdn = n.elb.dnsname
  else
    if n.has_key?("ec2")
      if n.ec2.has_key?("public_hostname")
        server_fqdn = n.ec2.public_hostname
      else
        server_fqdn = n.ipaddress #VPC
      end
    else
      server_fqdn = n.fqdn
    end
  end
  ssh_sites_result << {:fqdn => server_fqdn, :name => n[:ec2tag][:name]}
  if (n.run_list.run_list_items.include?("role[magento-webonly]"))
    ssh_sites_as_web_servers << server_fqdn
  end
end

Chef::Log.info("Jenkins SSH remote hosts: #{ssh_sites_result}")
Chef::Log.info("Jenkins SSH remote hosts as web servers: #{ssh_sites_as_web_servers}")
Chef::Log.info("Jenkins SSH registered remote hosts: #{node[:jenkins][:server][:enabled_remote_hosts]}")


# SSH sites template
template "SSH Wrapper config" do
  path "#{node[:jenkins][:server][:home]}/org.jvnet.hudson.plugins.SSHBuildWrapper.xml"
  source "org.jvnet.hudson.plugins.SSHBuildWrapper.xml.erb"
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
  mode "0644"
  variables(
    :SSH_SITES => ssh_sites_result
  )
end

############ TODO ---- decide what changed (new servers | stoped | terminated) and operate jenkins jobs
ssh_sites_need_restart = false
ssh_sites_result.each do |n|
  if node[:jenkins][:server][:enabled_remote_hosts].include? n[:fqdn]
    # TODO check somehow if server is up | down | .... and decide what to do with jenkins job: disable | enable | build
  else
    # This means server is new discovered
    # create job
    # TODO make here case-switch for diferent server types: mysql | magento | monitoring | maintenance 
    # in order to load different job templates
    job_name3 = "remote-SSH--#{n[:name]}--(#{n[:fqdn]})"
    job_config3 = File.join(node[:jenkins][:server][:home], "#{job_name3}-config.xml")

    jenkins_job job_name3 do
      action :nothing
      config job_config3
    end

    template job_config3 do
      source "job_config_CHEF_client_remote.xml.erb"
      owner node[:jenkins][:server][:user]
      group node[:jenkins][:server][:group]
      variables :job_name => job_name3, :remote_host => n
      notifies :update, resources(:jenkins_job => job_name3), :immediately
    end

    file job_config3 do
      action :delete
      backup false
    end
    node[:jenkins][:server][:enabled_remote_hosts] << n[:fqdn]
	ssh_sites_need_restart = true
  end
end


#### A single job for all remote ssh commands to restart web servers ####
job_name_rws = "remote-SSH--all-web-servers"
job_config_rws = File.join(node[:jenkins][:server][:home], "#{job_name_rws}-config.xml")

jenkins_job job_name_rws do
  action :nothing
  config job_config_rws
end

template job_config_rws do
  source "job_config_CHEF_client_remote_restart_webserver.xml.erb"
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
  variables :job_name => job_name_rws, :SSH_SITES_WEB_SERVERS => ssh_sites_as_web_servers 
  notifies :update, resources(:jenkins_job => job_name_rws), :immediately
end

file job_config_rws do
  action :delete
  backup false
end

###### TODO - check for terminated instances

###### Hardcoded ssh jobs for maintenance page #######
jenkins_ssh_nodes.each do |n|
  if (n.run_list.run_list_items.include?("role[maintenance-page-check-load]") ||
      n.run_list.run_list_items.include?("role[maintenance-page]") ||
      n.run_list.run_list_items.include?("role[maintenance-page-switch-on]") ||
      n.run_list.run_list_items.include?("role[maintenance-page-switch-off]"))

	# find server fqdn
    server_fqdn = ""
    if n.has_key?("jenkins") && n.jenkins.has_key?("elb")
      server_fqdn = n.elb.dnsname
    else
      if n.has_key?("ec2")
        if n.ec2.has_key?("public_hostname")
          server_fqdn = n.ec2.public_hostname
        else
          server_fqdn = n.ipaddress #VPC
        end
      else
        server_fqdn = n.fqdn
      end
    end

	
	# automatic job
    job_name3 = "remote-SSH--maintenance-page--automatic-check"
    job_config3 = File.join(node[:jenkins][:server][:home], "#{job_name3}-config.xml")

    jenkins_job job_name3 do
      action :nothing
      config job_config3
    end

    template job_config3 do
      source "job_config_CHEF_client__maintenance_remote.xml.erb"
      owner node[:jenkins][:server][:user]
      group node[:jenkins][:server][:group]
      variables :job_name => job_name3, :remote_host => server_fqdn
      notifies :update, resources(:jenkins_job => job_name3), :immediately
    end

    file job_config3 do
      action :delete
      backup false
    end

	
	# switch on job
    job_name3 = "remote-SSH--maintenance-page--switch-on"
    job_config3 = File.join(node[:jenkins][:server][:home], "#{job_name3}-config.xml")

    jenkins_job job_name3 do
      action :nothing
      config job_config3
    end

    template job_config3 do
      source "job_config_CHEF_client__maintenance_switch_on_remote.xml.erb"
      owner node[:jenkins][:server][:user]
      group node[:jenkins][:server][:group]
      variables :job_name => job_name3, :remote_host => server_fqdn
      notifies :update, resources(:jenkins_job => job_name3), :immediately
    end

    file job_config3 do
      action :delete
      backup false
    end

	
	# switch off job
    job_name3 = "remote-SSH--maintenance-page--switch-off"
    job_config3 = File.join(node[:jenkins][:server][:home], "#{job_name3}-config.xml")

    jenkins_job job_name3 do
      action :nothing
      config job_config3
    end

    template job_config3 do
      source "job_config_CHEF_client__maintenance_switch_off_remote.xml.erb"
      owner node[:jenkins][:server][:user]
      group node[:jenkins][:server][:group]
      variables :job_name => job_name3, :remote_host => server_fqdn
      notifies :update, resources(:jenkins_job => job_name3), :immediately
    end

    file job_config3 do
      action :delete
      backup false
    end
  end
end


if ssh_sites_need_restart == true
  jenkins_server "Safe Restart"
end