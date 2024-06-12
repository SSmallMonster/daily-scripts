#! /bin/bash

! (which nmcli > /dev/null 2>&1) && echo "no nmcli found in $PATH"

# check params
usage="input error
example:
	$(basename "$0") <interface_name> <address/netmask> <gateway_address>
	$(basename "$0") ens192 10.6.118.80/16 10.6.0.1
"

[ $# != 3 ] && echo -n "$usage" && exit 1
if_name=$1
if_address=$2
if_gateway=$3

! (nmcli c show $if_name > /dev/null 2>&1) && \
nmcli c add type ethernet ifname $if_name con-name $if_name && \
echo "ifname $if_name created"

nmcli c modify $if_name ipv4.addresses $if_address
nmcli c modify $if_name ipv4.gateway $if_gateway
nmcli c modify $if_name ipv4.method manual

nmcli c up $if_name > /dev/null
if [ $? != 0 ];
then
    echo "failed to configure $if_name"
    nmcli c del $if_name
else
    echo "$if_name configured successfully!"
fi

