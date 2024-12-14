#!/bin/bash
cd $(cd "$(dirname "$0")" && pwd)

key1=`pwd`
datetime=`date "+%Y-%m-%d.%H:%M:%S"`

key2="skynet"
ps aux |grep $key1|grep $key2|grep -v grep|grep -v "/bin/bash"|awk '{print $2}'|xargs kill -9
ret=`ps aux |grep $key1|grep $key2|grep -v grep|grep -v "/bin/bash"|awk '{print $11}'`
echo "kill "$key1" "$key2" "$ret
