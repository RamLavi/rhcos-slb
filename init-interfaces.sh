#!/usr/bin/env bash

set -ex

is_con_exists_by_uuid() {
	local con_uuid=$1
	if [[ $(nmcli -t -f UUID con show | grep -w "$con_uuid") ]]; then
		return 0 # true
	fi
	return 1 # false
}

is_con_active_by_uuid() {
	local con_uuid=$1
	if [[ $(nmcli -t -f UUID con show --active | grep -w "$con_uuid") ]]; then
		return 0 # true
	fi
	return 1 # false
}

get_con_uuid_from_device() {
	dev_name=$1
	local con_name=$(nmcli -g GENERAL.CONNECTION dev show "$dev_name")
	local con_uuid=$(nmcli -f CONNECTION.UUID con show "$con_name" | awk '{print $2}')
	echo "$con_uuid"
}

if [[ ! -f /boot/mac_addresses ]] ; then
  echo "no mac address configuration file found .. exiting"
  exit 1
fi

primary_mac=$(cat /boot/mac_addresses | awk -F= '/PRIMARY_MAC/ {print $2}' | tr '[A-Z]' '[a-z]')
secondary_mac=$(cat /boot/mac_addresses | awk -F= '/SECONDARY_MAC/ {print $2}' | tr '[A-Z]' '[a-z]')

default_device=""
secondary_device=""
default_connection_name=""
secondary_connection_name=""
default_connection_uuid=""
secondary_connection_uuid=""

for dev in $(nmcli device status | awk '/ethernet/ {print $1}'); do
  dev_mac=$(nmcli -g GENERAL.HWADDR dev show $dev | sed -e 's/\\//g' | tr '[A-Z]' '[a-z]')
  case $dev_mac in
    $primary_mac)
      default_device=$dev
      default_connection_uuid=$(get_con_uuid_from_device "$dev")
      ;;
    $secondary_mac)
      secondary_device=$dev
      secondary_connection_uuid=$(get_con_uuid_from_device "$dev")
      ;;
    *)
      ;;
   esac
done

echo -e "default dev: $default_device (CONNECTION.UUID $default_connection_uuid)\nsecondary dev: $secondary_device (CONNECTION.UUID $secondary_connection_uuid)"
if [[ -z "$default_device" ]] || [[ -z "$secondary_device" ]]; then
	echo "error: primary/secondary device name not found"
	exit 1
fi

if ! $(is_con_exists_by_uuid "$default_connection_uuid"); then
	nmcli con add type ethernet \
	              conn.interface "$default_device" \
	              connection.autoconnect yes \
	              ipv4.method auto
	default_connection_uuid=$(get_con_uuid_from_device "$default_device")
fi
if ! $(is_con_active_by_uuid "$default_connection_uuid"); then
	nmcli con up uuid "$default_connection_uuid"
fi

if ! $(is_con_exists_by_uuid "$secondary_connection_uuid"); then
	nmcli con add type ethernet \
	              conn.interface "$secondary_device" \
	              connection.autoconnect no \
	              ipv4.method disabled
	secondary_connection_uuid=$(get_con_uuid_from_device "$secondary_device")
fi
if $(is_con_active_by_uuid "$secondary_connection_uuid"); then
	nmcli con down uuid "$secondary_connection_uuid"
fi
