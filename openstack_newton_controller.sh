#! /bin/sh
read -p "Please input your MYSQL Password: " password      # 提示使用者輸入
read -p "Please input your controller ip: " controller
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y cloud-archive:newton
sudo apt-get update && sudo apt-get -y dist-upgrade
sudo apt-get install -y python-openstackclient
sudo apt-get install -y mariadb-server python-pymysql

touch /etc/mysql/mariadb.conf.d/openstack.cnf
echo "[mysqld]
bind-address = ${controller}

default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8" >> /etc/mysql/mariadb.conf.d/openstack.cnf

sudo service mysql restart
sudo mysql_secure_installation

sudo apt-get install -y rabbitmq-server
sudo rabbitmqctl add_user openstack ${password}
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"
sudo apt-get install -y memcached python-memcache

sudo sed -i 's@-l 127.0.0.1@-l '${controller}'@' /etc/memcached.conf
sudo service memcached restart



mysql -u root -p${password} -e "drop database keystone;"
mysql -u root -p${password} -e "drop database glance;"
mysql -u root -p${password} -e "drop database nova;"
mysql -u root -p${password} -e "drop database nova_api;"
mysql -u root -p${password} -e "drop database neutron;"
mysql -u root -p${password} -e "drop database cinder;"


mysql -u root -p${password} -e "CREATE DATABASE keystone;"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '${password}';"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${password}';"

mysql -u root -p${password} -e "CREATE DATABASE glance;"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost'  IDENTIFIED BY '${password}';"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '${password}';"

mysql -u root -p${password} -e "CREATE DATABASE nova;"
mysql -u root -p${password} -e "CREATE DATABASE nova_api;"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${password}';"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '${password}';"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '${password}';"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '${password}';"

mysql -u root -p${password} -e "CREATE DATABASE neutron;" 
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost'  IDENTIFIED BY '${password}';"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%'  IDENTIFIED BY '${password}';"



mysql -u root -p${password} -e "CREATE DATABASE cinder;"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '${password}';"
mysql -u root -p${password} -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%'  IDENTIFIED BY '${password}';"


echo "manual" | sudo tee /etc/init/keystone.override
sudo apt-get install keystone apache2 libapache2-mod-wsgi -y

sudo sed -i 's@#admin_token = <None>@admin_token =21d7fb48086e09f30d40be5a5e95a7196f2052b2cae6b491@' /etc/keystone/keystone.conf
sudo sed -i 's~connection = sqlite:////var/lib/keystone/keystone.db~connection = mysql+pymysql://keystone:'${password}'@'${controller}'/keystone~' /etc/keystone/keystone.conf
sudo sed -i 's@#servers = localhost:11211@servers = '${controller}':11211@' /etc/keystone/keystone.conf
sudo sed -i 's@#provider = uuid@provider = fernet@' /etc/keystone/keystone.conf



sudo keystone-manage db_sync
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone


sudo keystone-manage bootstrap --bootstrap-password ${password} \
--bootstrap-admin-url http://${controller}:35357/v3/ \
--bootstrap-internal-url http://${controller}:35357/v3/ \
--bootstrap-public-url http://${controller}:5000/v3/ \
--bootstrap-region-id RegionOne

echo "ServerName ${controller}">> /etc/apache2/apache2.conf
sudo ln -s /etc/apache2/sites-available/keystone.conf /etc/apache2/sites-enabled
sudo service apache2 restart
sudo rm -f /var/lib/keystone/keystone.db

export OS_USERNAME=admin
export OS_PASSWORD=${password}
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${controller}:35357/v3
export OS_IDENTITY_API_VERSION=3

openstack project create --domain default \
--description "Service Project" service 
openstack project create --domain default \
--description "Demo Project" demo
openstack user create --domain default --password ${password} demo

openstack role create user
openstack role add --project demo --user demo user




export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${password}
export OS_AUTH_URL=http://${controller}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

openstack user create --domain default --password ${password} --email glance@example.com glance

openstack role add --project service --user glance admin

openstack service create --name glance  --description "OpenStack Image service" image

openstack endpoint create --region RegionOne \
image public http://${controller}:9292

openstack endpoint create --region RegionOne \
image internal http://${controller}:9292

openstack endpoint create --region RegionOne \
image admin http://${controller}:9292


sudo apt-get install -y glance
sudo sed -i 's~sqlite_db = /var/lib/glance/glance.sqlite~connection = mysql+pymysql://glance:'${password}'@'${controller}'/glance~' /etc/glance/glance-api.conf
sudo sed -i 'N; s@\[keystone_authtoken\]\n@\[keystone_authtoken\]\nauth_uri = http://'${controller}':5000\nauth_url = http://'${controller}':35357\nmemcached_servers = '${controller}':11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = '${password}'@' /etc/glance/glance-api.conf
sudo sed -i 's@#flavor = keystone@flavor = keystone@' /etc/glance/glance-api.conf
sudo sed -i 's@#stores = file,http@stores = file,http@' /etc/glance/glance-api.conf
sudo sed -i 's@#default_store = file@default_store = file@' /etc/glance/glance-api.conf
sudo sed -i 's@#filesystem_store_datadir = /var/lib/glance/images@filesystem_store_datadir = /var/lib/glance/images/@' /etc/glance/glance-api.conf

sudo sed -i 's~sqlite_db = /var/lib/glance/glance.sqlite~connection = mysql+pymysql://glance:'${password}'@'${controller}'/glance~' /etc/glance/glance-registry.conf
sudo sed -i 'N; s@\[keystone_authtoken\]@\[keystone_authtoken\]\nauth_uri = http://'${controller}':5000\nauth_url = http://'${controller}':35357\nmemcached_servers = '${controller}':11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = '${password}'@' /etc/glance/glance-registry.conf
sudo sed -i 's@#flavor = keystone@flavor = keystone@' /etc/glance/glance-registry.conf

sudo glance-manage db_sync
sudo service glance-registry restart
sudo service glance-api restart
sudo rm -f /var/lib/glance/glance.sqlite

sudo wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

openstack image create "cirros-0.3.4-x86_64" \
--file cirros-0.3.4-x86_64-disk.img \
--disk-format qcow2 --container-format bare \
--public



export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${password}
export OS_AUTH_URL=http://${controller}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2


openstack user create --domain default --password ${password} --email nova@example.com nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create --region RegionOne \
compute public http://${controller}:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
compute internal http://${controller}:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
compute admin http://${controller}:8774/v2.1/%\(tenant_id\)s


sudo apt-get install -y nova-api nova-conductor nova-consoleauth \
nova-novncproxy nova-scheduler 





sudo sed -i 'N; s@\[DEFAULT\]\n@\[DEFAULT\]\n\nmy_ip = '${controller}'\nrpc_backend = rabbit\nauth_strategy = keystone\nuse_neutron = True\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver\n@' /etc/nova/nova.conf

sudo sed -i 'N; s~\[database\]\n~\[database\]\nconnection = mysql+pymysql://nova:'${password}'@'${controller}'/nova\n#~' /etc/nova/nova.conf
sudo sed -i 'N; s~\[api_database\]\n~\[api_database\]\nconnection = mysql+pymysql://nova:'${password}'@'${controller}'/nova_api\n#~' /etc/nova/nova.conf
sudo sed -i 's@lock_path=/var/lock/nova@lock_path=/var/lib/nova/tmp@' /etc/nova/nova.conf



echo "
[vnc]
vncserver_listen = ${controller}
vncserver_proxyclient_address = ${controller}

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

" >> /etc/nova/nova.conf


sudo nova-manage api_db sync
sudo nova-manage db sync

sudo service nova-api restart
sudo service nova-consoleauth restart
sudo service nova-scheduler restart
sudo service nova-conductor restart
sudo service nova-novncproxy restart

sudo rm -f /var/lib/nova/nova.sqlite
openstack compute service list


export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${password}
export OS_AUTH_URL=http://${controller}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

openstack user create --domain default --password ${password} --email neutron@example.com neutron

openstack role add --project service --user neutron admin

openstack service create --name neutron --description "OpenStack Networking" network

openstack endpoint create --region RegionOne \
network public http://${controller}:9696

openstack endpoint create --region RegionOne \
network internal http://${controller}:9696

openstack endpoint create --region RegionOne \
network admin http://${controller}:9696

sudo apt-get install -y neutron-server neutron-plugin-ml2

sudo sed -i 's@#service_plugins =@service_plugins =router@' /etc/neutron/neutron.conf
sudo sed -i 's@#allow_overlapping_ips = false@allow_overlapping_ips = True@' /etc/neutron/neutron.conf
sudo sed -i 's@#rpc_backend = rabbit@rpc_backend = rabbit@' /etc/neutron/neutron.conf
sudo sed -i 's@#auth_strategy = keystone@auth_strategy = keystone@' /etc/neutron/neutron.conf
sudo sed -i 's@#notify_nova_on_port_status_changes = true@notify_nova_on_port_status_changes = true@' /etc/neutron/neutron.conf
sudo sed -i 's@#notify_nova_on_port_data_changes = true@notify_nova_on_port_data_changes = true@' /etc/neutron/neutron.conf
sudo sed -i 's~connection = sqlite:////var/lib/neutron/neutron.sqlite~connection = mysql+pymysql://neutron:'${password}'@'${controller}'/neutron~' /etc/neutron/neutron.conf
sudo sed -i 's@#rabbit_host = localhost@rabbit_host = '${controller}'@' /etc/neutron/neutron.conf
sudo sed -i 's@#rabbit_userid = guest@rabbit_userid = openstack@' /etc/neutron/neutron.conf
sudo sed -i 's@#rabbit_password = guest@rabbit_password = '${password}'@' /etc/neutron/neutron.conf
sudo sed -i 's@# From keystonemiddleware.auth_token@# From keystonemiddleware.auth_token\nauth_uri = http://'${controller}':5000\nauth_url = http://'${controller}':35357\nmemcached_servers = '${controller}':11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = '${password}'\n@' /etc/neutron/neutron.conf
sudo sed -i 'N; s@\[nova\]\n@\[nova\]\n\nauth_url = http://'${controller}':35357\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = nova\npassword = '${password}'@' /etc/neutron/neutron.conf

sudo sed -i 's@#type_drivers = local,flat,vlan,gre,vxlan,geneve@type_drivers = flat,vlan,gre,vxlan@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#tenant_network_types = local@tenant_network_types = vxlan@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#mechanism_drivers =@mechanism_drivers =openvswitch,l2population@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#extension_drivers =@extension_drivers = port_security@' /etc/neutron/plugins/ml2/ml2_conf.ini

sudo sed -i 's@# VXLAN VNI IDs that are available for tenant network allocation (list value)@# VXLAN VNI IDs that are available for tenant network allocation (list value)\nvni_ranges = 1:1000@' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's@#enable_ipset = true@enable_ipset = true@' /etc/neutron/plugins/ml2/ml2_conf.ini


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
service_metadata_proxy = True
metadata_proxy_shared_secret = ${password}
" >> /etc/nova/nova.conf



sudo neutron-db-manage --config-file /etc/neutron/neutron.conf \
--config-file /etc/neutron/plugins/ml2/ml2_conf.ini \
upgrade head
sudo service nova-api restart
sudo service neutron-server restart
neutron ext-list

sudo apt-get install openstack-dashboard -y

sudo sed -i 's@OPENSTACK_HOST = "127.0.0.1"@OPENSTACK_HOST = "'${controller}'"@' /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@127.0.0.1:11211@'${controller}':11211@' /etc/openstack-dashboard/local_settings.py

echo "SESSION_ENGINE = 'django.contrib.sessions.backends.cache'" >> /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@OPENSTACK_KEYSTONE_URL = "http://%s:5000/v2.0" % OPENSTACK_HOST@OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST@' /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@_member_@user@' /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = False@OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True@' /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN @OPENSTACK_KEYSTONE_DEFAULT_DOMAIN @' /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@#OPENSTACK_API_VERSIONS@OPENSTACK_API_VERSIONS@' /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@#    "identity": 3,@    "identity": 3,@' /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@#    "image": 2,@    "image": 2,@' /etc/openstack-dashboard/local_settings.py
sudo sed -i 's@#    "volume": 2,@    "volume": 2,\n}@' /etc/openstack-dashboard/local_settings.py
sudo service apache2 reload
sudo service apache2 restart

openstack flavor create --ram 1024 --disk 10 --vcpus 1 test

echo "
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${password}
export OS_AUTH_URL=http://${controller}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
" >> admin-openrc
