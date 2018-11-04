#
# Cookbook:: al-xenserver-chef
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

include_recipe 'apt'
package %w( build-essential redis-server libpng-dev git python-minimal libvhdi-utils lvm2 )

apt_repository 'nodesource' do
  uri 'https://deb.nodesource.com/node_8.x'
  components ['main']
  action :add
end

include_recipe 'nodejs'
include_recipe 'yarn'

directory node['xen']['orchestra']['install_path'] do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

git node['xen']['orchestra']['install_path'] do
  repository node['xen']['orchestra']['git']
  reference 'master'
  action :sync
  notifies :run, 'bash[yarn_update]', :immediately
end

bash 'yarn_update' do
  cwd node['xen']['orchestra']['install_path']
  code <<-EOH
    yarn
    yarn build
    EOH
  action :nothing
end

template "#{node['xen']['orchestra']['install_path']}/packages/xo-server/.xo-server.yaml" do
  source 'xo-server.yaml.erb'
  owner 'root'
  mode '0755'
  action :create
end

systemd_unit 'orchestra.service' do
  content <<-EOU.gsub(/^\s+/, '')
    [Unit]
    Description=xen-orchestra
    Wants=network-online.target

    [Service]
    Environment="DEBUG=xo:main"
    WorkingDirectory=#{node['xen']['orchestra']['install_path']}/packages/xo-server/
    ExecStart=/usr/bin/node bin/xo-server
    SyslogIdentifier=xo-server

    [Install]
    WantedBy=multi-user.target

  EOU
  action [:create, :enable]
  notifies :restart, 'service[orchestra]', :delayed
end

service 'orchestra' do
  action [:enable, :start]
end
