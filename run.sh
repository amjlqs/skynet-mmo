#!/bin/bash

# 先杀死所有skynet进程
cd $(cd "$(dirname "$0")" && pwd)
path=`pwd`
./stop.sh
echo "=============================================="
datetime=`date "+%Y-%m-%d.%H:%M:%S"`
echo $datetime" 正在启动数据服务..."
./skynet/skynet $path/etc/config &

