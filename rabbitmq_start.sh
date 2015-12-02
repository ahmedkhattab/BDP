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

get-remaining-pods() {
  $KUBE get pods --no-headers | wc -l
}

clean-up-rabbitmq() {
  echo "Cleaning up minions ... "
  $KUBE delete rc rabbitmq-controller
  $KUBE delete svc rabbitmq
}

start_rabbitmq() {

  clean-up-rabbitmq

	$KUBE	create -f rabbitmq/rabbitmq-controller.json
	$KUBE create -f rabbitmq/rabbitmq-service.json

	while true; do
		pending_pods=$(get-pending-pods)
		if [[ $pending_pods == 0 ]]; then
			break
		else
			echo "Waiting for rabbitmq pod to start"
			sleep 5
		fi
	done

}

