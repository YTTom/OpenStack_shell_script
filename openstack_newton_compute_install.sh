#! /bin/sh
read -p "Please input your controller ip: " controller      
read -p "Please input your controller external ip: " external
read -p "Please input this node ip: " compute      
read -p "Please input your passwd: " password      
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y cloud-archive:newton
sudo apt-get update && sudo apt-get -y dist-upgrade

###install nova
sudo apt-get install -y nova-compute

sudo sed -i 's@enabled_apis@enabled_apis = osapi_compute,metadata#enabled_apis@' /etc/nova/nova.conf
sudo sed -i 's@lock_path@lock_path = /var/lib/nova/tmp#lock_path@' /etc/nova/nova.conf
sudo sed -i "s@\[DEFAULT\]@\[DEFAULT\]\nauth_strategy = keystone\nrpc_backend = rabbit\nuse_neutron = True\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver\nmy_ip = ${compute} @" /etc/nova/nova.conf


echo "
[vnc]
enabled = False
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = ${compute}
novncproxy_base_url = http://${external}:6080/vnc_auto.html

[oslo_messaging_rabbit]
rabbit_host = ${controller}
rabbit_userid = openstack
rabbit_password = ${password}

[keystone_authtoken]
auth_uri = http://${controller}:5000
auth_url = http://${controller}:35357
memcached_servers = ${controller}:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = ${password}

[glance]
api_servers = http://${controller}:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

" >> /etc/nova/nova.conf

sudo service nova-compute restart
sudo rm -f /var/lib/nova/nova.sqlite


echo "
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
">> /etc/sysctl.conf

modprobe br_netfilter
lsmod |grep  br_netfilter
cat /etc/modules |grep br_netfilter
sudo sysctl -p

cat /etc/modules |grep br_netfilter

sudo apt-get install -y neutron-openvswitch-agent

sudo sed -i 's@#verbose@verbose=True\n#@' /etc/neutron/neutron.conf
sudo sed -i 's@#rpc_backend@rpc_backend=rabbit\n#@' /etc/neutron/neutron.conf
sudo sed -i 's@#auth_strategy@auth_strategy@' /etc/neutron/neutron.conf
sudo sed -i 's@#core_plugin@core_plugin=ml2@' /etc/neutron/neutron.conf
sudo sed -i 's@#service_plugins@service_plugins=router\n#@' /etc/neutron/neutron.conf
sudo sed -i 's@#allow_overlapping_ips @allow_overlapping_ips = True\n#@' /etc/neutron/neutron.conf
sudo sed -i 's@connection@#connection\n#@' /etc/neutron/neutron.conf
sudo sed -i "N; s@\[oslo_messaging_rabbit\]\n@\n\[oslo_messaging_rabbit\]\nrabbit_host = ${controller}\nrabbit_userid = openstack\nrabbit_password =${password}\n  @" /etc/neutron/neutron.conf
sudo sed -i "N; s@\[keystone_authtoken\]\n@\n\[keystone_authtoken\]\nauth_uri = http://${controller}:5000\nauth_url = http://${controller}:35357\nmemcached_servers = ${controller}:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = ${password} @" /etc/neutron/neutron.conf
sudo sed -i 's@#local_ip@local_ip = '${compute}' \n#@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#tunnel_types@tunnel_types = vxlan \n#@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#l2_population@l2_population =True \n#@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#prevent_arp_spoofing@prevent_arp_spoofing =True \n#@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#enable_security_group@enable_security_group =True \n#@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#firewall_driver@firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver \n#@' /etc/neutron/plugins/ml2/openvswitch_agent.ini

echo "
[neutron]
url = http://${controller}:9696
auth_url = http://${controller}:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = ${password}
" >> /etc/nova/nova.conf


sudo service nova-compute restart
sudo service openvswitch-switch restart
sudo service neutron-openvswitch-agent restart

echo "
[spice]
agent_enabled=false
enabled=true
html5proxy_base_url=http://${controller}:6082/spice_auto.html
keymap=en-us
server_listen=0.0.0.0
server_proxyclient_address=${compute}
agent_enabled=false
" >> /etc/nova/nova.conf
