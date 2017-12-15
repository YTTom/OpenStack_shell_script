#! /bin/sh
neutron net-create ext-net --router:external \
--provider:physical_network external \
--provider:network_type flat

 neutron subnet-create ext-net 140.128.98.0/26 \
--allocation-pool start=140.128.98.40,end=140.128.98.50 \
--disable-dhcp --gateway 140.128.98.62 \
--name ext-subnet

neutron net-create demo-net

neutron subnet-create demo-net 192.168.1.0/24 \
--gateway 192.168.1.1 \
--dns-nameserver 8.8.8.8 \
--name demo-subnet

neutron router-create demo-router

neutron router-interface-add demo-router demo-subnet

neutron router-gateway-set demo-router ext-net