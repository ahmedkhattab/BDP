#!/bin/bash
KUBE="/home/khattab/kubernetes-1.1.2/cluster/kubectl.sh"

get-spark-master() {
  SPARK_IP=$($KUBE get nodes -o=template '-t={{(index (index .items 0).status.addresses 2).address}}')
}

get-host-ip() {
  $KUBE get pod $1 -o template -t={{.status.hostIP}}
}

get-pod-status() {
  $KUBE get pod $1 -o template -t={{.status.phase}}
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
  echo "Cleaning up minions ... "
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

  echo "Waiting for spark master to start"
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

  echo "Launching 3 spark workers"
  $KUBE create -f spark/spark-worker-controller.json
	
	while true; do
		pending_pods=$(get-pending-pods)
		if [[ $pending_pods == 0 ]]; then
			break
		else
			echo "Waiting for $pending_pods spark workers to start"
			sleep 5
		fi
	done

  $KUBE create -f spark/spark-driver.json

  $KUBE get pods

  get-spark-master

	echo "Spark UI accessible through: http://$SPARK_IP:31314"
}

