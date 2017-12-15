#! /bin/sh
read -p "Please input your controller ip: " controller
read -p "Please input your network ip: " network
read -p "Please input your passwd: " password   

sudo apt-get install -y software-properties-common
sudo add-apt-repository -y cloud-archive:newton
sudo apt-get update && sudo apt-get -y dist-upgrade
echo "
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
">> /etc/sysctl.conf

sudo sysctl -p

sudo apt-get install -y neutron-plugin-ml2 neutron-l3-agent \
neutron-dhcp-agent neutron-metadata-agent \
neutron-openvswitch-agent

sudo sed -i 's@#verbose = true@verbose = true@' /etc/neutron/neutron.conf
sudo sed -i 's@#rpc_backend = rabbit@rpc_backend = rabbit@' /etc/neutron/neutron.conf
sudo sed -i 's@#auth_strategy = keystone@auth_strategy = keystone@' /etc/neutron/neutron.conf
sudo sed -i 's@#service_plugins =@service_plugins = router@' /etc/neutron/neutron.conf
sudo sed -i 's@#allow_overlapping_ips = false@allow_overlapping_ips = True@' /etc/neutron/neutron.conf

sudo sed -i 's@connection = sqlite:////var/lib/neutron/neutron.sqlite@#connection = sqlite:////var/lib/neutron/neutron.sqlite@' /etc/neutron/neutron.conf
sudo sed -i 's@#rabbit_host = localhost@rabbit_host = '${controller}'@' /etc/neutron/neutron.conf
sudo sed -i 's@#rabbit_userid = guest@rabbit_userid = openstack@' /etc/neutron/neutron.conf
sudo sed -i 's@#rabbit_password = guest@rabbit_password = '${password}'@' /etc/neutron/neutron.conf
sudo sed -i 'N; s@\[keystone_authtoken\]\n@\[keystone_authtoken\]\nauth_uri = http://'${controller}':5000\nauth_url = http://'${controller}':35357\nmemcached_servers = '${controller}':11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = '${password}'@' /etc/neutron/neutron.conf

sudo sed -i 's@#type_drivers = local,flat,vlan,gre,vxlan,geneve@type_drivers = flat,vlan,gre,vxlan@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#tenant_network_types = local@tenant_network_types = vxlan@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#mechanism_drivers =@mechanism_drivers =openvswitch,l2population@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#extension_drivers =@extension_drivers =port_security@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#flat_networks =@flat_networks = external\n#@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 'N; s@\[ml2_type_vxlan\]@\[ml2_type_vxlan\]\nvni_ranges = 1:1000@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#enable_ipset = true@enable_ipset = true@' /etc/neutron/plugins/ml2/ml2_conf.ini

sudo sed -i 's@#local_ip = <None>@local_ip = '${network}'@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#bridge_mappings =@bridge_mappings = external:br-ex@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#tunnel_types =@tunnel_types = vxlan@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#l2_population = false@l2_population = True@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#prevent_arp_spoofing = true@prevent_arp_spoofing = true@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#enable_security_group = true@enable_security_group = True@' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sudo sed -i 's@#firewall_driver = <None>@firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver@' /etc/neutron/plugins/ml2/openvswitch_agent.ini

sudo sed -i 's@#verbose = true@verbose = true@' /etc/neutron/l3_agent.ini
sudo sed -i 's@#interface_driver = <None>@interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver@' /etc/neutron/l3_agent.ini
sudo sed -i 's@#external_network_bridge = br-ex@external_network_bridge =@' /etc/neutron/l3_agent.ini

sudo sed -i 's@#verbose = true@verbose = true@' /etc/neutron/dhcp_agent.ini
sudo sed -i 's@#interface_driver = <None>@interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver@' /etc/neutron/dhcp_agent.ini
sudo sed -i 's@#dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq@dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq@' /etc/neutron/dhcp_agent.ini
sudo sed -i 's@#enable_isolated_metadata = false@enable_isolated_metadata = True@' /etc/neutron/dhcp_agent.ini
sudo sed -i 's@#dnsmasq_config_file =@dnsmasq_config_file = /etc/neutron/dnsmasq-neutron.conf@' /etc/neutron/dhcp_agent.ini
echo 'dhcp-option-force=26,1450' | sudo tee /etc/neutron/dnsmasq-neutron.conf


sudo sed -i 's@#nova_metadata_ip = 127.0.0.1@nova_metadata_ip = '${controller}'@' /etc/neutron/metadata_agent.ini
sudo sed -i 's@#metadata_proxy_shared_secret =@metadata_proxy_shared_secret ='${password}'@' /etc/neutron/metadata_agent.ini



