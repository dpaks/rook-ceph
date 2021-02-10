#!/bin/bash

NS="rook-ceph"

RED='\033[0;31m'
GREEN='\033[0;32m'
BROWN='\033[0;33m'
PURPLE='\e[35m'
NC='\033[0m'
CHECK="\xE2\x9C\x94"
CROSS="\xE2\x9D\x8C"

elapsed=0
while true;
do
    ips=$(kubectl get svc -n $NS -l app=rook-ceph-mon -o=jsonpath="{.items[*]['spec.clusterIP']}")
    rt=$?
    ar=($ips)
    if [[ $rt != 0 || ${#ar[@]} < 1 ]]; then
        if (( $elapsed >= 300 )); then
            printf "\n${RED}Wait for ceph monitoring services timedout.${NC}\n\n"
            exit 1
        fi
        elapsed=$(( $elapsed + 30 ))
        sleep 30s
        continue
    fi
    break
done

arr=($ips)
ceph_ips_list_no_quote=""
i=0
while [ $i -lt ${#arr[@]} ]
do
    ceph_ips_list="\"${arr[$i]}:6789\""
    ceph_ips_list_no_quote="${ceph_ips_list_no_quote}${arr[$i]}:6789"
    i=$[$i+1]
    if [ $i -ne ${#arr[@]} ]; then
        ceph_ips_list="${ceph_ips_list},"
        ceph_ips_list_no_quote="${ceph_ips_list_no_quote},"
    fi
done

d=$(kubectl get secret rook-ceph-admin-keyring -n $NS -o=jsonpath={.data.keyring} | base64 -d)
echo $d
secret=$(grep key <<< $d | awk '{print $3}' | base64 -w0 | base64 -d)
fsNamespace=$(kubectl get CephFilesystem -n $NS -oname | cut -d'/' -f 2)

printf "${BROWN} Run the following command to mount and test ceph ${NC}\n"
printf "\n${GREEN} sudo mount -t ceph $ceph_ips_list_no_quote:/ /mnt -o name=admin,secret=$secret,mds_namespace=$fsNamespace,_netdev \n${NC}"

