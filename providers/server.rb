# Cookbook Name:: jenkins
# Based on hudson
# Provider:: server
#
# Author:: Valeriu Craciun

def action_srestart
   jenkins_cli "safe-restart"
end

def action_reloadconfig
   jenkins_cli "reload-configuration"
end
