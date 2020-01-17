#!/bin/sh
set -e

chown mosquitto:mosquitto -R /var/lib/mosquitto
chown mosquitto:mosquitto -R /var/log/mosquitto
chown mosquitto:mosquitto -R /opt/mosquitto

if [ "$1" = 'mosquitto' ]; then
	exec /usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf
fi

exec "$@"
