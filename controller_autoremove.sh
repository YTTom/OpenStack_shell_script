#! /bin/sh

sudo apt-get autoremove --purge -y mariadb-server python-pymysql
sudo apt-get autoremove --purge -y rabbitmq-server
sudo apt-get autoremove --purge -y memcached python-memcache
sudo apt-get autoremove --purge keystone apache2 libapache2-mod-wsgi -y
sudo apt-get autoremove --purge -y glance

sudo apt-get autoremove --purge -y nova-api nova-conductor nova-consoleauth \
nova-novncproxy nova-scheduler 
sudo apt-get autoremove --purge -y neutron-server neutron-plugin-ml2
sudo apt-get autoremove --purge openstack-dashboard
mysql -u root -p${password} -e "drop database keystone;"
mysql -u root -p${password} -e "drop database glance;"
mysql -u root -p${password} -e "drop database nova;"
mysql -u root -p${password} -e "drop database nova_api;"
mysql -u root -p${password} -e "drop database neutron;"
mysql -u root -p${password} -e "drop database cinder;"
