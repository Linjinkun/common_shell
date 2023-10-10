#! /bin/bash
 #v202207
#set -euo pipefail
#modprobe ip_conntrack_ftp
#modprobe ip_nat_ftp

init(){
     
    allow_ip=(
        117.29.164.90
        103.230.237.230
    )
    
    open_port=(
        80
    )
    iface=`ip route get 114.114.114.114|grep dev |awk '{print $5}'`
    chain="xxxxx"
    ipsetname="whitelist"
    hasdocker=false
    if command -v docker >/dev/null 2>&1; then
        hasdocker=true
    fi
}

set_filter(){
    for port in ${open_port[@]}
    do
    iptables -t raw -I PREROUTING -m addrtype --dst-type LOCAL -i $iface -p tcp --dport $port -j MARK --set-mark 1
    #iptables -A $chain ! -o docker0 -p tcp --dport $port -j ACCEPT
    done
    iptables -A $chain -m mark --mark 1 -j ACCEPT
    iptables -A $chain -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A $chain -p icmp -j ACCEPT
    iptables -A $chain -m set --match-set $ipsetname src -j ACCEPT
    iptables -A $chain -j DROP
    iptables -I INPUT -i $iface -j $chain 
    if [ $hasdocker = true ]; then
        iptables -I DOCKER-USER -i $iface -j $chain
    fi
}

reset_ipset(){
    ipset create $ipsetname hash:net >/dev/null 2>&1
    ipset flush $ipsetname >/dev/null 2>&1
    for addr in ${allow_ip[@]}
    do
    ipset add $ipsetname $addr
    done
}

flush_filter(){
    iptables -F $chain ; iptables -N $chain >/dev/null 2>&1
    iptables -F INPUT ; iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    if [ $hasdocker = true ]; then
        iptables -F DOCKER-USER
        iptables -A DOCKER-USER -j RETURN
    fi
    iptables -t raw -F PREROUTING
    iptables -t raw -P PREROUTING ACCEPT
}

reset_ipv6_filter(){
    ip6tables -F $chain ; ip6tables -N $chain >/dev/null 2>&1
    ip6tables -F INPUT ; ip6tables -P INPUT ACCEPT
    for port in ${open_port[@]}
    do
    ip6tables -A $chain -p tcp --dport $port -j ACCEPT
    done
    ip6tables -A $chain -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A $chain -p icmpv6 -j ACCEPT
    #ip6tables -A $chain -m set --match-set $ipsetname src -j ACCEPT
    ip6tables -A $chain -j DROP
    ip6tables -I INPUT -i $iface -j $chain 
}

init
reset_ipset
flush_filter
reset_ipv6_filter
set_filter 
