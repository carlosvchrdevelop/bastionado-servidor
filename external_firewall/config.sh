#!/bin/sh

# Actualizamos los repositorios
apk update

# Instalamos Iptables e Ip6tables para configurar reglas de firewall
# Instalamos iptables-persistent para hacer permanentes los cambios
apk add iptables ip6tables iptables-persistent

# Permitir el tráfico saliente desde la red local hacia Internet
iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT

# Permitir el tráfico entrante relacionado y establecido
iptables -A FORWARD -i eth1 -o eth0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Habilitar NAT para redirigir el tráfico desde la red local hacia Internet
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

# Permitimos hacia el servidor SSH (por puerto no estandar 2202), http y https
iptables -A FORWARD -p tcp --dport 20222 -j ACCEPT
iptables -A FORWARD -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp --dport 443 -j ACCEPT

# Permitimos conexiones a la interfaz de loopback
iptables -I INPUT 1 -i lo -j ACCEPT

# Permitimos solo las peticiones ICMP imprescindibles
iptables -A INPUT -m conntrack -p icmp --icmp-type 3 --cstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack -p icmp --icmp-type 11 --cstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack -p icmp --icmp-type 12 --cstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack -p icmp --icmp-type 3 --cstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack -p icmp --icmp-type 11 --cstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack -p icmp --icmp-type 12 --cstate NEW,ESTABLISHED,RELATED -j ACCEPT

# Rechazamos el resto de conexiones no contempladas
iptables -P INPUT DROP
iptables -P FORWARD DROP
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP

# Guardamos los cambios de forma persistente
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

# Habilitamos el enrutamiento IPv4 en el servidor
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
