# Apply updates and cleanup Apt cache
#
apt-get update ; apt-get -y dist-upgrade
apt-get -y autoremove
apt-get -y clean

echo "# Reset the machine-id value. This has known to cause issues with DHCP"
#
echo "" | tee /etc/machine-id >/dev/null
truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

echo "# Reset any existing cloud-init state"
#
cloud-init clean -s -l

# cleanup current ssh keys so templated VMs get fresh key
rm -f /etc/ssh/ssh_host_*

# add check for ssh keys on reboot...regenerate if neccessary
tee /etc/rc.local >/dev/null <<EOL
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#

# By default this script does nothing.
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
exit 0
EOL

# make the script executable
chmod +x /etc/rc.local

# reset the machine-id (DHCP leases in 18.04 are generated based on this... not MAC...)
#echo "" | tee /etc/machine-id >/dev/null

# remove files that break customization spec @ VMWare
rm -rf /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
rm -rf /etc/cloud/cloud.cfg.d/99-installer.cfg

echo "# disable swap for K8s"
swapoff --all
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

echo "# cleanup shell history and shutdown for templating"
history -c
history -w
