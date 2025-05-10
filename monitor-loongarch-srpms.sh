#!/bin/bash
 
# 要监视的目录
WATCH_DIR="/root/rpmbuild/SRPMS/"
 
# 确保inotifywait已安装
if ! command -v inotifywait &> /dev/null; then
    echo "inotifywait 未安装。请先安装 inotify-tools。"
    exit 1
fi
 
# 使用inotifywait监视目录
inotifywait -m -e create -e modify "$WATCH_DIR" --format '%w%f' | while read NEW_FILE
do
    echo "检测到新文件: $NEW_FILE，等待文件创建完成"
    size1=$(stat -c %s "$NEW_FILE" 2>/dev/null || echo 0)
    sleep 1
    size2=$(stat -c %s "$NEW_FILE" 2>/dev/null || echo 0)

    while [ "$size1" != "$size2" ]; do
        size1=$size2
        sleep 1
        size2=$(stat -c %s "$NEW_FILE" 2>/dev/null || echo 0)
    done

    # 执行rb命令，假设rb命令在当前路径下可执行
    # 根据实际情况修改命令路径或参数
    ssh "root@192.168.235.29" "/root/rpmbuild/SPECS/rbb /mnt/loongarch/$NEW_FILE"
    RENO=$?
    if [ $RENO == 0 ]; then
	    cp $NEW_FILE /mnt/magicx86/root/rpmbuild/SRPMS/$(basename $NEW_FILE) -fv
	    echo "$NEW_FILE" >> rebuildfromloongarch
    else
	    echo "编译出错，请检查并手工处理"
    fi
done

