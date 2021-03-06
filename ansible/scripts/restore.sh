#!/bin/sh

# This script creates a backup tgz file containing the following assets:
#
# 1. Dumps from Postgres of the CKAN databases.
# 2. A copy of the SOLR data directory.
# 3. A copy of CKAN's filestore directory.

# Set some useful variables.
USER_HOME=$(eval echo ~${SUDO_USER})

# Download from S3
cd $USER_HOME
python download.py $1

# Untar/gunzip it
rm -rf restored
mkdir restored
mv "backup-$1.tgz" restored/
cd restored
tar xfvz "backup-$1.tgz"
cd ..

# Kick some services in an appropriate way so restore isn't blocked.
sudo service apache2 stop
sudo service postgresql restart

# Restore the databases.
sudo /usr/lib/ckan/default/bin/paster --plugin=ckan db clean -c /etc/ckan/default/production.ini
sudo /usr/lib/ckan/default/bin/paster --plugin=ckan db load -c /etc/ckan/default/production.ini restored/ckan_default.sql
sudo su - postgres -c "pg_restore -d datastore_default -c" < "restored/datastore_default.dump"

# Copy the filestore directory into the backup directory.
sudo cp -r restored/default/* /var/lib/ckan/default

# Restart Apache
sudo service apache2 start

# Reindex SOLR:
/usr/lib/ckan/default/bin/paster --plugin=ckan user list -c /etc/ckan/default/production.ini search-index rebuild
