#!/bin/sh

/usr/bin/echo 'devops:Admin!23Admin' | /usr/bin/sudo /usr/sbin/chpasswd
script_dir=$(cd "$(dirname "$0")"; pwd)
cd $script_dir

pravite_ip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
public_ip=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
ssh_user=devops
ssh_pass="Admin!23Admin"

# allow password authentication of ssh
sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# copy template inventory and modify
sudo cp -f inventory.standalone.sudo inventory

# modify host and home_url
sudo sed -i "s/1.1.1.1/${pravite_ip}/g" inventory
sudo sed -i "s/homeurl=esc.paraview.cn/homeurl=${public_ip}/g" inventory
sudo sed -i "s/gateway_mgmt_url=gateway.paraview.cn/gateway_mgmt_url=${public_ip}/g" inventory

# modify ansible ssh user and password
sudo sed -i "s/ansible_ssh_user=root/ansible_ssh_user=${ssh_user}/g" inventory
sudo sed -i "s/ansible_ssh_pass=123456/ansible_ssh_pass=${ssh_pass}/g" inventory

# modify ansible sudo password (if needed) (some as the ssh user's password)
sudo sed -i "s/ansible_become_pass=123456/ansible_become_pass=${ssh_pass}/g" inventory

# download iam trial lic
rm -f iam-600-trial.lic
curl --user-agent "paraview" -o iam-600-trial.lic 'https://paraview-public-trial-license.s3.ap-southeast-1.amazonaws.com/iam-600-trial.lic'
lic_string="$(cat iam-600-trial.lic)"

# make update_lic.sql
cat > ./update_lic.sql << EOF
-- import trial license
truncate table sys_license;
INSERT INTO sys_license VALUES (1111111111111111111, 'sysadmin', 'sysadmin', '2025-01-01 00:00:00', '2025-01-01 00:00:00', 'paraview', '${lic_string}');
EOF

# add sql to idm-6.0.0.1.sql
cat update_lic.sql >> ${script_dir}/tarballs/sql/6.0.2/6.0.0.1/6.0.0.1-idm.sql
rm -f update_lic.sql

# begin install
sudo bash install.sh
#nohup sudo bash install.sh > ./install.log 2>&1 &

#deny password authentication of ssh
sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart sshd