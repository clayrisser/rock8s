#!/bin/sh

if [ -d /vagrant ] || dmidecode -s system-product-name 2>/dev/null | grep -qi "virtualbox"; then
    if ! id vagrant >/dev/null 2>&1; then
        pw useradd -n vagrant -s /bin/sh -m -G wheel,admins -w yes
        echo 'vagrant' | pw usermod vagrant -h 0
        mkdir -p /home/vagrant/.ssh
        echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key' > /home/vagrant/.ssh/authorized_keys
        chown -R vagrant:vagrant /home/vagrant/.ssh
        chmod 700 /home/vagrant/.ssh
        chmod 600 /home/vagrant/.ssh/authorized_keys
        echo '%vagrant ALL=NOPASSWD:ALL' > /usr/local/etc/sudoers.d/vagrant
        chmod 440 /usr/local/etc/sudoers.d/vagrant
    fi
fi
/usr/local/bin/php /usr/local/libexec/initialize.php
