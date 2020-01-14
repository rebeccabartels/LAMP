#!/usr/bin/env bash

# Check if user is running as root
if [[ $$EUID -ne 0 ]]; then
  echo "Please run this script with sudo."
  exit 1
fi

apt update -y
################################
# INSTALL AND CONFIGURE APACHE #
################################
apt-get install apache2

# Check Internet
ping -c http://icanhazip.com 2>&1 /dev/null 
if [[ "$?" -ne 0]]; then
  >&2 echo "Seems like you have an issue with your Internet connection."
  >&2 echo "Check your connectivity before proceeding."
  exit 1
fi

# Get your public IP address
IP=$(curl http://icanhazip.com)

# Add a global ServerName to Apache configuration to suppress warnings
# Be sure to use ``>>``, NOT ``>`!
echo "ServerName $IP" >> /etc/apache2/apache2.conf

# Verify configuration
apache2ctl configtest
if [[ "$?" -ne 0]]; then
  >&2 echo "Error verifying configuration in '/etc/apache2/apache2.conf'."
fi

# Ensure server is running with new configuration
systemctl apache2 restart

# Launch server on boot
systemctl apache2 enable

# Update Firewall
ufw list
ufw allow 'Apache Full'
ufw status
ufw enable

################################
# INSTALL AND CONFIGURE PHP    #
################################
apt-get install php libapache2-mod-php php-mcrypt php-mysql

# Edit the DirectoryIndex line so `index.php` is before `index.html`
DIR_CONF="/etc/apache2/mods-enabled/dir.conf"
LINE_NUMBER=$(grep -n 'DirectoryIndex' ${DIR_CONF} | awk '{print $1}')

# Change `index.php` entry to `index.html`
sed "${LINE_NUMBER}s/index.php/index.html" ${DIR_CONF}

# Change first `index.html` entry to `index.php`
sed "${LINE_NUMBER}s/index.html/index.php" ${DIR_CONF}

# Create a test file w/ echo
echo '<?php phpinfo(); ?>' > /var/www/html/info.php

# check that the page contains the string "version"
curl "http://localhost/info.php" | grep -i 'version'
if [[ "$?" -ne 0 ]]; then
  >&2 echo "Error loading PHP info! Not removing '/var/www/html/info.php' so you can investigate..." 
else
  # Remove the test file for security
  rm /var/www/html/info.php
fi
