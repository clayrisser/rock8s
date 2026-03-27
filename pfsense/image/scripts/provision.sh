#!/bin/sh

echo 'autoboot_delay="0"' >> /boot/loader.conf
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
echo 'sshd_enable="YES"' >> /etc/rc.conf
service sshd restart
pkg install -y pfSense-pkg-haproxy
pkg install -y pfSense-pkg-acme
cp /tmp/initialize.php /usr/local/libexec/initialize.php
cp /tmp/initialize.sh /usr/local/libexec/initialize
cp /tmp/startup.sh /usr/local/etc/rc.d/startup
chmod 755 \
    /usr/local/etc/rc.d/startup \
    /usr/local/libexec/initialize \
    /usr/local/libexec/initialize.php
echo 'startup_enable="YES"' >> /etc/rc.conf
