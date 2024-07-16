#!/bin/bash

HOSTS=(
  "root@k8s-master"
  "root@k8s-node01"
  "root@k8s-node02"
  "root@k8s-node03"
  "root@k8s-register"
)


pcount=$#
if ((pcount == 0)); then
  echo "command can not be null !"
  exit
fi

for host in "${HOSTS[@]}"; do
  echo ---------------- $host ----------------
  ssh $host 'source /etc/profile;'$*
done

echo --------------- complete ---------------
