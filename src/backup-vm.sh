#!/bin/bash
set -e

date=$(date +%Y%m%d)
backup_dir='/srv/backup-vm'
maxTry=100

[ -d "$backup_dir" ] || mkdir -p $backup_dir

shutdown_domain () {
  name=$1

  virsh shutdown $name

  status=$(virsh list --all|grep $name|awk '{$1=$2=""; gsub (" ", "", $0); print $0}')
  until [ "$status" == "shutoff" ] || [ $maxTry -eq 0 ]; do
    sleep 1
    ((maxTry--))
    status=$(virsh list --all|grep $name|awk '{$1=$2=""; gsub (" ", "", $0); print $0}')
  done

  if [ $maxTry -eq 0 ]; then
  	echo "ERROR: Unable to shutdown domain $name"
  	return 1
  fi
}

start_domain () {
  name=$1
  virsh start $name
}

backup_domain () {
  name=$1
  container=$(virsh domblklist $name |grep images|awk '{print $2}')
  backup="$backup_dir/${container##*/}-$date"
  rsync -av $container $backup
}

help () {
  echo "Usage: $0 <domain-name>"
  exit
}


if [ $# -eq 0 ]; then
  help
fi

shutdown_domain $1
backup_domain $1
start_domain $1
