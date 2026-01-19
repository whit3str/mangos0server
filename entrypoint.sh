#!/bin/bash
cd /home/container

# Ensure config directory exists
mkdir -p etc

# Copy config dists if missing
if [ ! -f etc/mangosd.conf ]; then
    cp /opt/mangos/etc/mangosd.conf.dist etc/mangosd.conf || echo "No dist conf found (mangosd)"
fi
if [ ! -f etc/realmd.conf ]; then
    cp /opt/mangos/etc/realmd.conf.dist etc/realmd.conf || echo "No dist conf found (realmd)"
fi

# Link binaries if user wants to use ./bin paths (optional)
mkdir -p bin
ln -sf /opt/mangos/bin/mangosd bin/mangosd
ln -sf /opt/mangos/bin/realmd bin/realmd

# Internal IP/Startup Variable Replacement (Pterodactyl usually handles this, but custom logic here if needed)
# ...

# Launch
echo "Starting MangosZero..."
# Run realmd in background
/opt/mangos/bin/realmd &
REALM_PID=$!

# Run mangosd
/opt/mangos/bin/mangosd -c etc/mangosd.conf

# When mangosd exits, kill realmd
kill $REALM_PID
