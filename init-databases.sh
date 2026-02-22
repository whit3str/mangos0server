#!/bin/bash
# set -e intentionally removed: MySQL 8.0 compat warnings must not abort init

echo "Initializing Mangos Zero Databases..."

# Fix potential Windows line endings on all SQL files
find /database -name '*.sql' -exec sed -i 's/\r//' {} + 2>/dev/null || true

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
mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_CHAR < /database/Character/Setup/characterLoadDB.sql || { echo "ERROR: characterLoadDB.sql failed"; exit 1; }
mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_WORLD < /database/World/Setup/mangosdLoadDB.sql || { echo "ERROR: mangosdLoadDB.sql failed"; exit 1; }
mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_REALM < /database/Realm/Setup/realmdLoadDB.sql || { echo "ERROR: realmdLoadDB.sql failed"; exit 1; }

# Helper function to apply updates
apply_updates() {
    local DB_NAME=$1
    local UPDATE_PATH=$2
    
    if [ -d "$UPDATE_PATH" ]; then
        echo "Applying updates for $DB_NAME from $UPDATE_PATH..."
        for f in $(ls $UPDATE_PATH/*.sql 2>/dev/null | sort -V); do
            echo "Processing $f"
            mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_NAME < "$f" || echo "WARNING: $f returned an error (non-fatal)"
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

# Populate World Database (FullDB)
echo "Populating World Database..."
if [ -d "/database/World/Setup/FullDB" ]; then
    for f in $(ls /database/World/Setup/FullDB/*.sql 2>/dev/null | sort -V); do
         echo "Importing $f"
         mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_WORLD < "$f" || echo "WARNING: $f returned an error (non-fatal)"
    done
fi

# Insert default realm entry after full init
echo "Adding Default Realm..."
if [ -f "/database/Tools/updateRealm.sql" ]; then
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" $DB_REALM < /database/Tools/updateRealm.sql || echo "WARNING: updateRealm.sql returned an error (non-fatal)"
fi

echo "Database initialization complete."
