#批量建游戏数据库
#!/bin/bash
BEGIN=2
END=2
SQL1="CREATE DATABASE IF NOT EXISTS actor_s default charset binary"
SOURCE1="source /修改成自己的路径/sql/actor.sql"

PASSWORD='xxxxxxx'
MYSQL="mysql -uroot -p${PASSWORD} --default-character-set=utf8 -A -N"

for ((i = $BEGIN; i <= $END; i++))
do
        sql="show databases like 'actor{i}'"
        result="$($MYSQL -e "$sql")"
        if [ ! $result ]; then
                sql1=${SQL1/"_s"/"${i}"}
                $MYSQL -e "$sql1"
                db="actor${i}"
                $MYSQL -D $db -e "$SOURCE1"
                echo $sql1
                echo "创建数据库$db成功"
        else
                echo "创建数据库actor_s${i},数据库已存在"
        fi
done

