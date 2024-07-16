#!/bin/bash
HOSTS=(
  "root@k8s-master"
  "root@k8s-node01"
  "root@k8s-node02"
  "root@k8s-node03"
  "root@k8s-register"
)

# 获取输入参数个数，如果没有参数，直接退出
pcount=$#
if ((pcount == 0)); then
  echo no args
  exit
fi

# 获取文件名称
p1=$1
fname=$(basename $p1)
echo fname=$fname

# 获取上级目录到绝对路径
pdir=$(
  cd -P $(dirname $p1)
  pwd
)
echo pdir=$pdir

# 循环分发
for host in "${HOSTS[@]}"; do
  rsync -rvl $pdir/$fname $host:$pdir &
done

wait

echo --------------- complete ---------------
