#!/bin/bash
./~/kubernetes/cluster/kubectl.sh delete svc consul
./~/kubernetes/cluster/kubectl.sh delete pod amb-consul
./~/kubernetes/cluster/kubectl.sh delete svc ambari
./~/kubernetes/cluster/kubectl.sh delete pod amb-server
./~/kubernetes/cluster/kubectl.sh delete rc amb-slave-controller

./~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/consul.json
./~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/consul-service.json
./~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/ambari-hdfs.json
./~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/ambari-service.json
./~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/ambari-slave.json
