#!/bin/bash
KUBE="/home/khattab/kubernetes-1.1.2/cluster/kubectl.sh"

get-spark-master() {
  CASSANDRA_IP=$($KUBE get nodes -o=template '--template={{(index (index .items 0).status.addresses 2).address}}')
}

get-pending-pods() {
  $KUBE get pods | grep "Pending" | wc -l
}

clean-up-cassandra() {
  echo "Cleaning up minions ... "
  $KUBE delete rc cassandra
  $KUBE delete svc cassandra
	while true; do
		remaining=$($KUBE get pods --no-headers | grep "cassandra" | wc -l)
		if [[ $remaining == 0 ]]; then
      echo "done"
			break
		else
			echo -n "."
			sleep 5
		fi
	done
}

start_cassandra() {

  clean-up-cassandra

	$KUBE create -f cassandra/cassandra-controller.yaml
	$KUBE create -f cassandra/cassandra-service.yaml

	while true; do
		pending_pods=$(get-pending-pods)
		if [[ $pending_pods == 0 ]]; then
			break
		else
			echo "Waiting for cassandra pods to start"
			sleep 5
		fi
	done
	echo "Cassandra accessible through: http://$CASSANDRA_IP:31317" >> stdout
  echo -e "${color_yellow} Cassandra accessible through: http://$CASSANDRA_IP:31317 .${color_norm}"
}

