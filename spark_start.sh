#!/bin/bash
KUBE="/home/khattab/kubernetes-1.1.2/cluster/kubectl.sh"

get-spark-master() {
  SPARK_IP=$($KUBE get nodes -o=template '--template={{(index (index .items 0).status.addresses 2).address}}')
}

get-host-ip() {
  $KUBE get pod $1 -o template --template={{.status.hostIP}}
}

get-pod-status() {
  $KUBE get pod $1 -o template --template={{.status.phase}}
}


get-pending-pods() {
  $KUBE get pods | grep "Pending" | wc -l
}

get-namenode-pod() {
  get-ambari-server
  json= curl -s --user admin:admin http://$AMBARI_IP:$AMBARI_PORT/api/v1/clusters/multi-node-hdfs/services/HDFS/components/NAMENODE -o namenode.json
  NAMENODE_HOST=$(jq -r '.host_components[] | select(.HostRoles.component_name=="NAMENODE") | .HostRoles.host_name' namenode.json)
  echo $NAMENODE_HOST
}


clean-up-spark() {
  echo "Spark: Cleaning up minions ... "
  $KUBE delete rc spark-worker-controller
  $KUBE delete svc spark-master
  $KUBE delete pod spark-master
  $KUBE delete pod spark-driver

	while true; do
		remaining=$($KUBE get pods --no-headers | grep "spark" | wc -l)
		if [[ $remaining == 0 ]]; then
      echo "done"
			break
		else
			echo -n "."
			sleep 5
		fi
	done
}

start_spark() {

  clean-up-spark

	$KUBE	create -f spark/spark-master.json
	$KUBE create -f spark/spark-master-service.json

  echo "Spark: Waiting for spark master to start"
	while true; do
		master_state=$(get-pod-status spark-master)
		if [[ "$master_state" == "Running" ]]; then
      echo ""
			break
		else
			echo -n "."
			sleep 5
		fi
	done

  $KUBE create -f spark/spark-worker-controller.json
	
  echo "Spark: waiting for 3 spark workers to start ..."
	while true; do
		pending_pods=$(get-pending-pods)
		if [[ $pending_pods == 0 ]]; then
			break
		else
			echo -n "."
			sleep 5
		fi
	done

  $KUBE create -f spark/spark-driver.json

  get-spark-master

  echo -e "${color_yellow} Spark UI accessible through: http://$SPARK_IP:31314 .${color_norm}"
	echo "Spark UI accessible through: http://$SPARK_IP:31314" >> stdout
}

