#!/bin/bash


""" installs the recent check_mk agent (inovation release) onto ubuntu
or centos machines and registers it on your monitoring site

By Mathias Decker
contact: mathias.decker@mdc-berlin.de
         github@mathiasdecker.de

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""



alias rm='rm'

# prepping some vars
hostname=$(hostname)
upperhostname=$(echo $hostname | tr '[a-z]' '[A-Z]')

if [ "$(whoami)" != "root" ]
then
	"run me as root or via sudo"
	exit
fi

if [[ $(cat /proc/version) == *centos* ]]
then
	for i in $(curl -s http://mathias-kettner.de/download/ | sed 's/<\/a><\/td><td align="right">/ /g' | sed -e :a -e 's/<[^>]*>//g;/</N;//ba' | cut -f1 -d" " | grep "[0-9]i[0-9]" | grep ".rpm")
	do
		curl -s -O http://mathias-kettner.de/download/$i
	done
	rm check_mk*scriptless*.rpm
	rm check_mk*oracle*.rpm
	yum -y install xinetd python
	rpm -i check_mk-agent*.rpm
	iptables -N CHECK_MK
	iptables -I INPUT -s 0/0 -p tcp --dport 6556 -j CHECK_MK
	iptables -I CHECK_MK -s you.monitoring.host -j ACCEPT
	iptables -A CHECK_MK -s 0/0 -j DROP
	/etc/init.d/iptables save
fi

if [[ $(cat /proc/version) == *ubuntu* ]]
then
	for i in $(curl -s http://mathias-kettner.de/download/ | sed 's/<\/a><\/td><td align="right">/ /g' | sed -e :a -e 's/<[^>]*>//g;/</N;//ba' | cut -f1 -d" " | grep "[0-9]i[0-9]" | grep ".deb")
	do
		curl -s -O http://mathias-kettner.de/download/$i
	done
	rm check-mk*oracle*.deb
	apt-get -y install xinetd python
	dpkg -i check-mk-agent_*.deb
	dpkg -i check-mk-agent*l*.deb
	

fi

/etc/init.d/xinetd start
mv /etc/xinetd.d/check_mk /tmp/check_mk
gw=$(route | grep default | sed "s/[ ]* / /g" | cut -f2 -d" ")

case $gw in
	141.80.181.1)
		cat /tmp/check_mk | sed 's/#only_from      = 127.0.0.1 10.0.20.1 10.0.20.2/only from = 127.0.0.1 141.80.181.120/g' > /etc/xinetd.d/check_mk
		;;
	141.80.183.1)
		cat /tmp/check_mk | sed 's/#only_from      = 127.0.0.1 10.0.20.1 10.0.20.2/only from = 127.0.0.1 141.80.183.120/g' > /etc/xinetd.d/check_mk
		;;
	*)
		cat /tmp/check_mk | sed 's/#only_from      = 127.0.0.1 10.0.20.1 10.0.20.2/only from = 127.0.0.1 141.80.40.67 141.80.40.69/g' > /etc/xinetd.d/check_mk
		;;
esac 

echo "register maschine to nagios"
curl -s "http://your.monitoring.host:5000/site/check_mk/wato.py?filled_in=edithost&_transid=-1&host=$upperhostname&contactgroups_use=on&attr_alias=&attr_ipaddress=&parents_0=&site=local&attr_tag_agent=cmk-agent%7Ctcp&attr_tag_criticality=prod&attr_tag_networking=lan&save=Save+%26+Finish&folder=&mode=newhost&_username=automation-user&_secret=automation-secret" > /dev/null
rm /tmp/check_mk
