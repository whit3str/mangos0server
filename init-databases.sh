#!/bin/bash
set -e

echo "Initializing Mangos Zero Databases..."

# Variables
DB_CHAR="character0"
DB_WORLD="mangos0"
DB_REALM="realmd"
DB_USER="mangos"
DB_PASS="mangos"

# Create Database and User
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS $DB_CHAR;
    CREATE DATABASE IF NOT EXISTS $DB_WORLD;
    CREATE DATABASE IF NOT EXISTS $DB_REALM;
    CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
    GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'%';
    FLUSH PRIVILEGES;
EOSQL

# Import Base Schemas
echo "Importing Base Schemas..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_CHAR < /database/Character/Setup/characterLoadDB.sql
mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_WORLD < /database/World/Setup/mangosdLoadDB.sql
mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_REALM < /database/Realm/Setup/realmdLoadDB.sql

# Helper function to apply updates
apply_updates() {
    local DB_NAME=$1
    local UPDATE_PATH=$2
    
    if [ -d "$UPDATE_PATH" ]; then
        echo "Applying updates for $DB_NAME from $UPDATE_PATH..."
        for f in $(ls $UPDATE_PATH/*.sql 2>/dev/null | sort -V); do
            echo "Processing $f"
            mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_NAME < "$f"
        done
    else
        echo "Directory $UPDATE_PATH does not exist, skipping updates for $DB_NAME."
    fi
}

# Apply Updates
# Character Updates
apply_updates $DB_CHAR "/database/Character/Updates/Rel21"
apply_updates $DB_CHAR "/database/Character/Updates/Rel22"

# World Updates
apply_updates $DB_WORLD "/database/World/Updates/Rel21"
apply_updates $DB_WORLD "/database/World/Updates/Rel22"

# Realm Updates
apply_updates $DB_REALM "/database/Realm/Updates/Rel21"
apply_updates $DB_REALM "/database/Realm/Updates/Rel22"

# Add Default Realm
echo "Adding Default Realm..."
if [ -f "/database/Tools/updateRealm.sql" ]; then
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_REALM < /database/Tools/updateRealm.sql
fi

# Populate World Database (FullDB)
echo "Populating World Database..."
# Usually located in World/Setup/FullDB
if [ -d "/database/World/Setup/FullDB" ]; then
    for f in $(ls /database/World/Setup/FullDB/*.sql 2>/dev/null | sort -V); do
         echo "Importing $f"
         mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_WORLD < "$f"
    done
fi

echo "Database initialization complete."
