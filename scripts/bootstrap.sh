#!/usr/bin/env bash

SAMPLE_DATA=$1
MAGE_VERSION="1.9.1.0"
DATA_VERSION="1.9.0.0"

NUKE=${2}

## Can also be passed via ARGV[0]
DBHOST='localhost'
DBUSER='muser'
DBPASS='password'
DBNAME='mdb'

# Set Perl:locales
# http://serverfault.com/questions/500764/dpkg-reconfigure-unable-to-re-open-stdin-no-file-or-directory
# --------------------
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales

export DEBIAN_FRONTEND=noninteractive

# Update Apt
# --------------------
apt-get update

# Install Apache & PHP
# --------------------
apt-get install -y apache2
apt-get install -y php5
apt-get install -y libapache2-mod-php5
apt-get install -y php5-mysqlnd php5-curl php5-xdebug php5-gd php5-intl php-pear php5-imap php5-mcrypt php5-ming php5-ps php5-pspell php5-recode php5-sqlite php5-tidy php5-xmlrpc php5-xsl php-soap

php5enmod mcrypt

# Install GIT
apt-get install -y git

# Delete default apache web dir and symlink mounted vagrant dir from host machine
# --------------------
rm -rf /var/www/html
mkdir -p /vagrant/httpdocs

ln -fs /vagrant/httpdocs /var/www/html

# Replace contents of default Apache vhost
# --------------------
VHOST=$(cat <<EOF
Listen 8080
<VirtualHost *:80>
  DocumentRoot "/var/www/html"
  ServerName localhost
  <Directory "/var/www/html">
    AllowOverride All
  </Directory>
</VirtualHost>
<VirtualHost *:8080>
  DocumentRoot "/var/www/html"
  ServerName localhost
  <Directory "/var/www/html">
    AllowOverride All
  </Directory>
</VirtualHost>
EOF
)

echo "$VHOST" > /etc/apache2/sites-enabled/000-default.conf

a2enmod rewrite
service apache2 restart

# Mysql
# --------------------
# Ignore the post install questions
export DEBIAN_FRONTEND=noninteractive


# Install MySQL quietly
echo -e '--> Installing Mysql 5.6'
apt-get -q -y install mysql-server-5.6
mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${DBNAME}"
mysql -u root -e "GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'${DBHOST}' IDENTIFIED BY '${DBPASS}'"
mysql -u root -e "FLUSH PRIVILEGES"


# Magento
# --------------------
# http://www.magentocommerce.com/wiki/1_-_installation_and_configuration/installing_magento_via_shell_ssh

# Download and extract
echo -e '--> Downloading Magento if required'
if [[ ! -f "/vagrant/httpdocs/index.php" ]] || [ 'true' == $NUKE ]; then
  cd /vagrant/httpdocs
  wget http://www.magentocommerce.com/downloads/assets/${MAGE_VERSION}/magento-${MAGE_VERSION}.tar.gz
  tar -zxvf magento-${MAGE_VERSION}.tar.gz
  mv magento/* magento/.htaccess .
  chmod -R o+w media var
  chmod o+w app/etc

  # Clean up downloaded file and extracted dir
  rm -rf magento*
fi


# Sample Data
echo -e '--> Install sample data if applicable'
if [[ $SAMPLE_DATA == "true" ]]; then
  cd /vagrant

  if [[ ! -f "/vagrant/magento-sample-data-${DATA_VERSION}.tar.gz" ]]; then
    # Only download sample data if we need to
    wget http://www.magentocommerce.com/downloads/assets/${DATA_VERSION}/magento-sample-data-${DATA_VERSION}.tar.gz
  fi

  tar -zxvf magento-sample-data-${DATA_VERSION}.tar.gz
  cp -R magento-sample-data-${DATA_VERSION}/media/* httpdocs/media/
  cp -R magento-sample-data-${DATA_VERSION}/skin/*  httpdocs/skin/
  mysql -u root magentodb < magento-sample-data-${DATA_VERSION}/magento_sample_data_for_${DATA_VERSION}.sql
  rm -rf magento-sample-data-${DATA_VERSION}
fi


# Run installer
echo -e '--> Installing Magento'
cd /vagrant/httpdocs
/usr/bin/php -f install.php --                \
  --license_agreement_accepted yes            \
  --locale en_US                              \
  --timezone "America/Los_Angeles"            \
  --default_currency USD                      \
  --db_host ${DBHOST}                         \
  --db_name ${DBNAME}                         \
  --db_user ${DBUSER}                         \
  --db_pass ${DBPASS}                         \
  --url "http://127.0.0.1:8080/"              \
  --use_rewrites yes                          \
  --use_secure no                             \
  --secure_base_url "http://127.0.0.1:8080/"  \
  --use_secure_admin no                       \
  --skip_url_validation yes                   \
  --admin_firstname Test                      \
  --admin_lastname Admin                      \
  --admin_email "admin@example.com"           \
  --admin_username ehime                      \
  --admin_password 'passw0rd' 2>&1 | tee ~/installer.log


# Turn on rewrites
# --------------------
echo -e '--> Enabling Rewrites'
curl -sSL https://goo.gl/kfNNbp -o shell/update-core-config.php
/usr/bin/php -f shell/update-core-config.php
/usr/bin/php -f shell/indexer.php reindexall


# Install n98-magerun
# --------------------
echo -e '--> Installing Magerun'
cd /vagrant/httpdocs
wget https://raw.github.com/netz98/n98-magerun/master/n98-magerun.phar
chmod +x ./n98-magerun.phar
mv ./n98-magerun.phar /usr/local/bin/


# Install modman
# --------------------
echo -e '--> Installing Modman'
su vagrant -c 'sudo bash < <(curl -s -L https://raw.github.com/colinmollenhour/modman/master/modman-installer)'
mv /home/vagrant/bin/modman /usr/local/bin


# Clone Module
# --------------------
echo -e '--> Cloning modules'
cd /vagrant/httpdocs
#modman init
#modman clone https://github.com/ehime/Magento-POST-Module.git
