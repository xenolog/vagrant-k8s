#!/bin/bash

if [[ "x${DEBUG}" != "x" ]] ; then
  set -x
fi

HOSTNAME=`hostname`
USAGE="Usage: $0 {start|stop}";

RACK_NO_SHORT=`printf "%d" $RACK_NO`
RACK_NO=`printf "%02d" $RACK_NO`
if [[ "${RACK_NO}" == "00" ]] ; then
  echo 'RACK_NO undefined, please define it as integer 1..253'
  exit 1
fi

NETNS_NAME="rack${RACK_NO}"
RUN_IN_NS="ip netns exec ${NETNS_NAME} "

etcd_fetch_data() {
  VETH_A="${NETNS_NAME}a"
  VETH_B="${NETNS_NAME}b"
  VETH_A_IP=`etcdctl get "/network_metadata/racks/${RACK_NO_SHORT}/veth/0"`
  VETH_B_IP=`etcdctl get "/network_metadata/racks/${RACK_NO_SHORT}/veth/1"`
  VETH_MASKLEN='30'
  PHY_IF=`etcdctl get "/network_metadata/racks/${RACK_NO_SHORT}/phy_if"`
  PHY_NET=`etcdctl get "/network_metadata/racks/${RACK_NO_SHORT}/subnet"`
  PHY_IP=`echo ${PHY_NET} | awk -F. '{print $1"."$2"."$3"."254}'`
  PHY_MASKLEN=`echo ${PHY_NET} | awk -F'/' '{print $2}'`
}

router_start() {
  ip netns | grep $NETNS_NAME
  if [[ $? == 0 ]] ; then
    echo "Router network namespace '${NETNS_NAME}' already exists. do nothing..."
    exit 1
  fi
  etcd_fetch_data
  # create netns
  ip netns add $NETNS_NAME
  $RUN_IN_NS sysctl -w net.ipv6.conf.all.disable_ipv6=1
  $RUN_IN_NS sysctl -w net.ipv6.conf.default.disable_ipv6=1
  $RUN_IN_NS sysctl -w net.ipv6.conf.lo.disable_ipv6=1
  #create veth
  ip link add dev $VETH_A type veth peer name $VETH_B
  ip link set $VETH_B netns $NETNS_NAME
  $RUN_IN_NS ip a add 127.0.0.1/8 dev lo
  $RUN_IN_NS ip l set up lo
  $RUN_IN_NS ip a add "${VETH_B_IP}/${VETH_MASKLEN}" dev $VETH_B
  $RUN_IN_NS ip l set up $VETH_B
  $RUN_IN_NS ip r add default dev $VETH_B
  ip a add "${VETH_A_IP}/${VETH_MASKLEN}" dev $VETH_A
  ip l set up $VETH_A

  # move PHYS interface into network namespace
  ip a flush $PHY_IF
  ip link set $PHY_IF netns $NETNS_NAME
  $RUN_IN_NS ip a add "${PHY_IP}/${PHY_MASKLEN}" dev $PHY_IF
  $RUN_IN_NS ip l set up $PHY_IF

}

router_stop() {
  etcd_fetch_data
  ip netns | grep $NETNS_NAME
  NO_NS=$?
  if [[ $NO_NS == 0 ]] ; then
    ip netns pids $NETNS_NAME | xargs -n1 kill -9
  fi
  ip link del dev $VETH_A type veth peer name $VETH_B
  if [[ $NO_NS == 0 ]] ; then
    ip netns del $NETNS_NAME
  fi
}

# main

if [ $# -ne 1 ]; then
    echo $USAGE
    exit 1
fi

case $1 in
    start) router_start
    ;;

    stop) router_stop
    ;;

    *) usage; exit $OCF_ERR_UNIMPLEMENTED
    ;;
esac
