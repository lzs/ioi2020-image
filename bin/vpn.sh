#!/bin/sh

check_ip()
{
	local IP=$1

	if expr "$IP" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
		return 0
	else
		return 1
	fi
}


do_config()
{

	CONF=$1

	if ! test -f $CONF; then
		echo "Can't read $CONF"
		exit 1
	fi

	WORKDIR=`mktemp -d`

	tar jxf $CONF -C $WORKDIR

	IP=$(cat $WORKDIR/vpn/ip.conf)
	MASK=$(cat $WORKDIR/vpn/mask.conf)

	if ! check_ip "$IP" || ! check_ip "$MASK"; then
		echo Bad IP numbers
		rm -r $WORKDIR
		exit 1
	fi

	echo "$IP" > /etc/tinc/vpn/ip.conf
	echo "$MASK" > /etc/tinc/vpn/mask.conf
	rm /etc/tinc/vpn/hosts/* 2> /dev/null
	cp $WORKDIR/vpn/hosts/* /etc/tinc/vpn/hosts/
	cp $WORKDIR/vpn/rsa_key.pub /etc/tinc/vpn/
	cp $WORKDIR/vpn/rsa_key.priv /etc/tinc/vpn/
	cp $WORKDIR/vpn/tinc.conf /etc/tinc/vpn

	rm -r $WORKDIR
	USERID=$(cat /etc/tinc/vpn/tinc.conf | grep Name | cut -d\  -f3)
	chfn -f "$USERID" ioi

	systemctl restart tinc@vpn

	return
}


case "$1" in
	start)
		systemctl start tinc@vpn
		;;
	restart)
		systemctl restart tinc@vpn
		;;
	status)
		systemctl status tinc@vpn
		;;
	config)
		do_config $2
		;;
	*)
		echo Not allowed
		;;
esac

# vim: ft=sh ts=4 sw=4 noet