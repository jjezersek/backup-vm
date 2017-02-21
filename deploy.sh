#!/bin/bash
set -e
debug=0

servers="pepe liza edo"

for name in $servers; do
	echo "Deploying to $name"
	scp -p src/backup-vm.sh root@$name:bin/
	scp -p cron.d/backup-vm root@$name:/etc/cron.d/
	
	ssh root@$name chmod 750 bin/backup-vm.sh
	ssh root@$name chmod 644 /etc/cron.d/backup-vm
done
