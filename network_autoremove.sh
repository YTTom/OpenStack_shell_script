#! /bin/sh

sudo apt-get autoremove --purge -y neutron-plugin-ml2 neutron-l3-agent \
neutron-dhcp-agent neutron-metadata-agent \
neutron-openvswitch-agent