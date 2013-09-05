#!/bin/bash
""" Installs the vmware OSP package onto centos or ubuntu

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


if [ "$(whoami)" != "root" ]
then
	"run me as root or via sudo"
	exit
fi

curl -U http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub
curl -U http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub
arch=$(uname -p)

if [[ $(cat /proc/version) == *centos* ]]
then
	echo "installing vmwaretools on centos"
	rpm --import VMWARE-PACKAGING-GPG-DSA-KEY.pub
	rpm --import VMWARE-PACKAGING-GPG-RSA-KEY.pub

	cat <<EOF > /etc/yum.repos.d/vmware-tools.repo
[vmware-tools]
name=VMware Tools
baseurl=http://packages.vmware.com/tools/esx/latest/rhel6/$arch
enabled=1
gpgcheck=1
EOF

	yum -y install vmware-tools-esx-kmods.$arch vmware-tools-esx
fi

if [[ $(cat /proc/version) == *ubuntu* ]]
then
	apt-key add VMWARE-PACKAGING-GPG-DSA-KEY.pub
	apt-key add VMWARE-PACKAGING-GPG-RSA-KEY.pub
	dist=$(lsb_release -c -s)
	cat <<EOF > /etc/apt/sources.list.d/vmware-tools.list
deb http://packages.vmware.com/tools/esx/latest/ubuntu $dist main
EOF
	apt-get update
	apt-get -y install vmware-tools-esx-kmods-$arch vmware-tools-esx

fi
