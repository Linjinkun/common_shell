#! /bin/bash
#v202207
#set -euo pipefail
#modprobe ip_conntrack_ftp
#modprobe ip_nat_ftp

init(){
    
    allow_ip=(
        127.0.0.1
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

reset_ipset(){
    ipset create $ipsetname hash:net >/dev/null 2>&1
    ipset flush $ipsetname >/dev/null 2>&1
    for addr in ${allow_ip[@]}
    do
        ipset add $ipsetname $addr
    done
}

flush_filter(){
    
    iptables -F $chain ;
    # 创建自定义的链，如果不存在就创建，存在也不报错
    iptables -N $chain >/dev/null 2>&1
    iptables -F INPUT ;
    
    # 设置 INPUT 链的默认策略为 ACCEPT，即接受所有进入系统的数据包
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    if [ $hasdocker = true ]; then
        iptables -F DOCKER-USER
        iptables -A DOCKER-USER -j RETURN
    fi
    
    iptables -t raw -F PREROUTING
    #设置 raw 表中 PREROUTING 链的默认策略为 ACCEPT，即接受所有经过 PREROUTING 链的数据包
    iptables -t raw -P PREROUTING ACCEPT
}

reset_ipv6_filter(){
    ip6tables -F $chain ;
    ip6tables -N $chain >/dev/null 2>&1
    ip6tables -F INPUT ;
    ip6tables -P INPUT ACCEPT
    
    for port in ${open_port[@]}
    do
        # -j 选项指定匹配规则后要执行的操作，接受（ACCEPT）匹配的数据包
        ip6tables -A $chain -p tcp --dport $port -j ACCEPT
    done
    
    ip6tables -A $chain -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A $chain -p icmpv6 -j ACCEPT
    #ip6tables -A $chain -m set --match-set $ipsetname src -j ACCEPT
    ip6tables -A $chain -j DROP
    ip6tables -I INPUT -i $iface -j $chain
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

init
reset_ipset
flush_filter
reset_ipv6_filter
set_filter
