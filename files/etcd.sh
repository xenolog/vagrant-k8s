#!/bin/bash

if [[ "z${DEBUG}" != "z" ]] ; then
  set -x
fi

HOSTNAME=`hostname`
USAGE="Usage: $0 {start|stop}";

etcd_fetch_data() {
  CONTAINER_NAME="${CONTAINER_NAME:-etcd.service}"
  ETCD_IPV4=${ETCD_IPV4}
  ETCD_BACKUP="/var/lib/etcd/backup.yaml"
  ETCD_PIDFILE="/var/run/${CONTAINER_NAME}.pid"
  if [[ -z ${ETCD_IPV4} ]] ; then
    echo "No IP address for ETCD endpoint given. Echo ETCD_IPV4 is empty."
    exit 1
  fi
}

etcd_start() {
  etcd_fetch_data

  if [[ ! -z $(docker ps | grep " ${CONTAINER_NAME}" | awk '{print $1}') ]] ; then
    echo "container with ETCD already running."
    exit 1
  fi

  mkdir -p /var/lib/etcd

  if [[ ! -z $(docker ps --all | grep " ${CONTAINER_NAME}" | awk '{print $1}') ]] ; then
    /usr/bin/docker rm ${CONTAINER_NAME} 2>&1 > /dev/null
  fi
  /usr/bin/docker run -d -p 2379:2379 -p 2380:2380 -p 4001:4001 --name ${CONTAINER_NAME} \
    -v /usr/share/ca-certificates/:/etc/ssl/certs quay.io/coreos/etcd:latest \
    etcd -name etcd0 -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 -listen-peer-urls http://0.0.0.0:2380 \
    -advertise-client-urls http://${ETCD_IPV4}:2379,http://${ETCD_IPV4}:4001
  sleep 1
  # create PID file for etcd process
  cn=$(docker ps --all | grep " ${CONTAINER_NAME}" | awk '{print $1}')
  ETCD_PPID=$(ps axf  | grep "containerd-shim ${cn}" | grep -v grep| awk '{print $1}')
  ETCD_PID=$(pstree -Ap  ${ETCD_PPID} | head -n1 | awk -F'\(\)' '{print $1}' | perl -pe 's/^.*etcd\((\d+)\).*$/$1/')
  echo $ETCD_PID > ${ETCD_PIDFILE}
  # restore saved etcd content
  if [[ -f ${ETCD_BACKUP} ]] ; then
    etcdtool -p http://127.0.0.1:4001 import -y -f yaml / ${ETCD_BACKUP} | true
  fi
}

etcd_stop() {
  etcd_fetch_data
  mkdir -p /var/lib/etcd
  etcdtool -p http://127.0.0.1:4001 export -f yaml / > ${ETCD_BACKUP}
  if [[ ! -z $(docker ps | grep " ${CONTAINER_NAME}" | awk '{print $1}') ]] ; then
    /usr/bin/docker kill ${CONTAINER_NAME} 2>&1 > /dev/null
  fi
  sleep 1
  /usr/bin/docker rm ${CONTAINER_NAME} 2>&1 > /dev/null
  rm ${ETCD_PIDFILE} | true
}

# main

if [[ $# -ne 1 ]]; then
    echo $USAGE
    exit 1
fi

case $1 in
    start) etcd_start
    ;;

    stop) etcd_stop
    ;;

    *) usage; exit $OCF_ERR_UNIMPLEMENTED
    ;;
esac
