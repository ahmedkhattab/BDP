#!/bin/bash
amb-copy-to-hdfs() {
  get-ambari-server-ip
  FILE_PATH=${1:?"usage: <FILE_PATH> <NEW_FILE_NAME_ON_HDFS> <HDFS_PATH>"}
  FILE_NAME=${2:?"usage: <FILE_PATH> <NEW_FILE_NAME_ON_HDFS> <HDFS_PATH>"}
  DIR=${3:?"usage: <FILE_PATH> <NEW_FILE_NAME_ON_HDFS> <HDFS_PATH>"}
  amb-create-hdfs-dir $DIR
  DATANODE=$(curl -si -X PUT "http://$AMBARI_SERVER_IP:50070/webhdfs/v1$DIR/$FILE_NAME?user.name=hdfs&op=CREATE" |grep Location | sed "s/\..*//; s@.*http://@@")
  DATANODE_IP=$(get-host-ip $DATANODE)
  curl -T $FILE_PATH "http://$DATANODE_IP:50075/webhdfs/v1$DIR/$FILE_NAME?op=CREATE&user.name=hdfs&overwrite=true&namenoderpcaddress=$AMBARI_SERVER_IP:8020"
}

amb-create-hdfs-dir() {
  get-ambari-server-ip
  DIR=$1
  curl -X PUT "http://$AMBARI_SERVER_IP:50070/webhdfs/v1$DIR?user.name=hdfs&op=MKDIRS" > /dev/null 2>&1
}

