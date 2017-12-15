#! /bin/sh
read -p "Please input your controller ip: " controller
read -p "Please input your MYSQL Password: " password      # 提示使用者輸入
read -p "Please input your external(up down) iterface: " interface

sudo service openvswitch-switch restart
sudo ovs-vsctl add-br br-ex
sudo ovs-vsctl add-port br-ex ${interface}
sudo ethtool -K ${interface} gro off
sudo service openvswitch-switch restart
sudo service neutron-openvswitch-agent restart
sudo service neutron-dhcp-agent restart
sudo service neutron-metadata-agent restart
sudo service neutron-l3-agent restart