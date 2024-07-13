#!/bin/bash

pcount=$#
if ((pcount == 0)); then
  echo "command can not be null !"
  exit
fi

user=$(whoami)

for ((i = 1; i <= 3; i++)); do
  echo ---------------- node0$i ----------------
  ssh $user@node0$i 'source /etc/profile;'$*
done

echo --------------- complete ---------------
