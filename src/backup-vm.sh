#!/bin/bash
# ---------------------------------------------------------------------------
# backup-vm - Do backup of virtual domain on host server.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.

# For usage, run "backup-vm -h" or see https://github.com/srvrco/getssl

# Revision history:
# 2017-02-21 Created (v0.1)
# 2017-03-15 Online snapshots of domain (v0.2)
# 2017-09-27 Automatic switch to offline backup if domain has additional disks (v0.3)
# ---------------------------------------------------------------------------

PROGNAME=${0##*/}
VERSION="0.3"

# defaults
backup_dir="/srv/backup-vm"
vm_description_dir="/etc/libvirt/qemu/"
date=$(date +%Y%m%d)
name="ssb$date"
offline=0
verbose=''

function show_help () {
  echo "Usage: $0 <domain-name>"
cat << EOF
Usage: ${0##*/} [-hov] [DOMAIN]
Do backup of virtual domain on host server.

    -h          display this help and exit
    -o          perform offline backup. First shutdown domain, copy and 
    			then start it up again.
    -v          verbose mode. Can be used multiple times for increased
                verbosity.

Note: To reach maximum accuracy with snapshot backup a few steps must 
be reached:
	1. install Qemu Guest Agent on domain
		apt install qemu-guest-agent or
		yum install qemu-guest-agent
	2. add serial device to domain
		<channel type='unix'>
			<source mode='bind'/>
			<target type='virtio' name='org.qemu.guest_agent.0'/>
			<address type='virtio-serial' controller='0' 
							bus='0' port='2'/>
		</channel>
EOF
}

# Name:		is_shutoff
#
# Description:
#	check if domain is shut off
#
# Parameters:
#	$domain		@string	remote domain name
# Return:
#	0	domain is stopped
#	1	domain is NOT stopped (some other state - running, paused etc.)
#
function is_shutoff () {
	local domain=$1
	output=$(virsh list --state-shutoff --name |grep $domain)
	return $?
}

# Name:		has_external_disk
#
# Description:
#	check if domain has external additional disk
#
# Parameters:
#	$domain		@string	remote domain name
# Return:
#	0	domain has disk
#	1	domain has no disk
#
function has_external_disk () {
	local domain=$1
	vm_description="$vm_description_dir/$domain.xml"
	grep --quiet "<disk type='block' device='disk'>" $vm_description
	return $?
		
}

# Name:	shutdown_domain
#
# Description:
#	Shut the domain down
#
# Parameters:
#	$domain		@string	remote domain name
# Return:
#	0	sucessfully stopped domain
#	1	domain is already stopped
#
function shutdown_domain () {
	local domain=$1
	local maxTry=100
	local status=1

	eval is_shutoff $domain
    status=$?
	if [ $status -eq 0 ] ; then
		if [ $status -eq 0 ]; then 
			echo "domain is already stopped"
		fi
		return 1
	fi

	virsh shutdown $domain
	until [ $status -eq 0 ] || [ $maxTry -eq 0 ]; do
		sleep 1
    	((maxTry--))
	 	eval is_shutoff $domain
	   	status=$?
	done
	if [ $status -eq 0 ]; then 
		echo "domain is now stopped"
	fi
}

# Name:	start_domain
#
# Description:
#	Start the domain
#
# Parameters:
#	$domain		@string	remote domain name
#
function start_domain () {
	if [ $status -eq 0 ]; then 
		echo "Starting domain"
	fi
	virsh start $1
}

# Name:	snapshot_backup
#
# Description:
#	Perform online snapshoot backup
#
# Parameters:
#	$domain		@string	remote domain name
#
function snapshot_backup() {
	local domain=$1
	local command="virsh snapshot-create-as --domain $domain $name --diskspec vda,file=$snapshot --disk-only --atomic --no-metadata"

	output=$($command --quiesce 2>/dev/null)
	status=$?
	if [ $status -ne 0 ] ; then
		output=$($command)
		echo "Warning: Backup of domain $domain may have no accurate file system. See help notes."
	fi
	if [ "$verbose" == "-v" ]; then
		echo "$output"
	fi

    cp $verbose $source $backup

	virsh blockcommit $domain vda --active --pivot > /dev/null
	status=$?
	if [ $status -eq 0 ]; then 
		if [ "$verbose" == "-v" ] ; then
			echo "Snapshot is successfully commited."
		fi
		rm $verbose $snapshot
	fi
}

# Name:	snapshot_backup
#
# Description:
#	Perform offline backup
#
# Parameters:
#	$domain		@string	remote domain name
#
function offline_backup () {
	local domain=$1

	shutdown_domain "$domain"
	local need_to_start=$?

    cp $verbose $source $backup

	if [ $need_to_start -ne 1 ]; then
		start_domain "$domain"
	fi
}



OPTIND=1
while getopts hov opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        o)	offline=1
        	;;
        v)  verbose='-v'
            ;;
        \?)
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

if [[ $# -eq 0 ]]; then
	show_help
	exit 0
fi
domain=$1
if [ "$verbose" == "-v" ]; then
	echo "Domain: $domain"
fi

#create room for backup
[ -d "$backup_dir" ] || mkdir -p $backup_dir


# Force offline backup if domain is offline, sic
eval is_shutoff $domain
status=$?
if [ $status -eq 0 ] ; then
	if [ "$verbose" == "-v" ]; then
		echo "Domain is offline. Force offline mode."
	fi
	offline=1
fi

# Does VM have additional disks
if [ $offline -eq 0 ] ; then
	eval has_external_disk $domain
	status=$?
	if [ $status -eq 0 ] ; then
		if [ "$verbose" == "-v" ]; then
			echo "Domain has additional additional disk. Force offline mode."
		fi
		offline=1
	fi
fi

# Set some variables
source=$(virsh domblklist $domain 2> /dev/null|grep vda|awk '{print $2}')
if [ "$source" == "" ]; then
	echo "Error: $domain is unknown"
	exit 1
fi
extension="${source##*.}"
snapshot="${source%/*}/$domain-$name.$extension"
backup="$backup_dir/$domain.$extension-$date"

# Do the job
if [ $offline -eq 0 ] ; then
	snapshot_backup "$domain"
else
	offline_backup "$domain"
fi
