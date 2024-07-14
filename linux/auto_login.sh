#!/bin/bash

HOST='root@192.168.100.10'
PASSWORD='981008'

expect -c "
spawn ssh $HOST
expect {
  \"yes/no\" {send \"yes\r\";exp_continue}
  \"password:\" {send \"$PASSWORD\r\";}
}
interact
"
