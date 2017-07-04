#!/bin/bash
set -e
debug=1
# DO NOT USE
# IT BREAKS VM

image_dir='/var/lib/libvirt/images'
backup_dir='/srv/backup-vm'
max_versions=3

[ -d "$image_dir" ] || (echo "Error: Source directory not found"; exit 1)
[ -d "$backup_dir" ] || mkdir -p $backup_dir

create_backup () {
	name=$1
	echo "Starting backup of $name"
	snapshot_name="$backup_dir/$name-$date.qcow2"
	
	if [ $debug -eq 1 ] ; then
		echo "qemu-img snapshot -c $date $container_name"
	fi
#	qemu-img snapshot -c $date $container_name
	# copy the snapshot out
	if [ $debug -eq 1 ] ; then
		echo "qemu-img convert -c -f qcow2 -O qcow2 $container_name $snapshot_name"
	fi
#	qemu-img convert -c -f qcow2 -O qcow2 $container_name $snapshot_name
	# delete the snapshot
	if [ $debug -eq 1 ] ; then
		echo "qemu-img snapshot -d $date $container_name"
	fi
#	qemu-img snapshot -d $date $container_name
	echo "    ... finished"
}

# todays date in squezzed format
date=`date +%Y%m%d`

# grab a list of all running domains
domains=`virsh list|grep running|awk '{print $2}'`

for name in $domains; do
	container_name=`find $image_dir |grep $name`
	container_fromat=`qemu-img info $container_name | grep --count "file format: qcow2"`
	if [ $container_fromat -eq 1 ]; then
		create_backup $name
	else
		echo "Warning: Snapshot backups only support qcow2 files"
	fi
done

# remove old versions of backup files
#find $backup_dir -mtime $max_versions -print -exec rm '{}' \;
