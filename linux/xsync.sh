#!/bin/bash
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

# 获取当前用户名称
user=$(whoami)

# 循环，分发到 node01 ~ node03
for ((i = 1; i <= 3; i++)); do
  echo ------------------- node0$i --------------
  rsync -rvl $pdir/$fname $user@node0$i:$pdir &
done
