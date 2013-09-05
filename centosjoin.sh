#!/bin/bash

""" joins a centos 6.x machine to an active directory domain
full setup with kerboros/GSSAPI and sssd

By Mathias Decker
contact: github@mathiasdecker.de
         
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

# syncing time
ntpdate ptbtime1.ptb.de

# prepping some vars
hostname=$(hostname)
upperhostname=$(echo $hostname | tr '[a-z]' '[A-Z]')

# installing depandancies
yum -y install sssd krb5-workstation krb5-server krb5-libs

# backing up configs
cp /etc/krb5.conf /etc/krb5.conf.orig
cp /etc/resolv.conf /etc/resolv.conf.orig
cp /etc/openldap/ldap.conf /etc/openldap/ldap.conf.orig
cp /etc/hosts /etc/hosts.orig
cp /etc/samba/smb.conf /etc/samba/smb.conf.orig

#cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.orig
cp /etc/nsswitch.conf /etc/nsswitch.conf.orig
cp /etc/pam.d/system-auth /etc/pam.d/system-auth.orig
cp /etc/pam.d/password-auth /etc/pam.d/password-auth.orig


##-------------------------------------------------------------------------------------------------------------------------
# writing krb5.conf
cat << 'EOF' > /etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = EXAMPLE.COM
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true

[realms]
 EXAMPLE.COM = {
  kdc = srv01.example.com
  kdc = srv04.example.com
  kdc = srv07.example.com
  admin_server = srv01.example.com
 }

[domain_realm]
 example.com = EXAMPLE.COM
 .example.com = EXAMPLE.COM
EOF

##-------------------------------------------------------------------------------------------------------------------------
# writing ldap.conf
cat << 'EOF' > /etc/openldap/ldap.conf
#
# LDAP Defaults
#

# See ldap.conf(5) for details
# This file should be world readable but not world writable.

#BASE	dc=example,dc=com
#URI	ldap://ldap.example.com ldap://ldap-master.example.com:666

#SIZELIMIT	12
#TIMELIMIT	15
#DEREF		never

TLS_CACERTDIR /etc/openldap/certs
SASL_MECH = gssapi
URI ldap://srv01.example.com/  ldap://srv04.example.com/  ldap://srv07.example.com/
BASE dc=mdc-berlin,dc=net
EOF

##-------------------------------------------------------------------------------------------------------------------------
# writing hosts file
cat <<EOF > /etc/hosts
127.0.0.1   $hostname $hostname.example.com localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF

##-------------------------------------------------------------------------------------------------------------------------
# writing resolv.conf
cat << 'EOF' > /etc/resolv.conf
domain example.com
search example.com example.com.
nameserver 10.0.0.1 10.0.0.2
EOF

##-------------------------------------------------------------------------------------------------------------------------
# writing sssd.conf
cat <<EOF > /etc/sssd/sssd.conf
[domain/default]
debug_level = 10
cache_credentials = True
id_provider = ldap
ldap_id_use_start_tls = False
ldap_sasl_mech = GSSAPI
ldap_force_upper_case_realm = True
ldap_krb5_keytab = /etc/krb5.keytab
ldap_sasl_authid = $upperhostname\$@EXAMPLE.COM
ldap_search_base = dc=mdc-berlin,dc=net
ldap_uri = ldap://srv01.example.com/,ldap://srv04.example.com/,ldap://srv07.example.com/
ldap_tls_cacertdir = /etc/openldap/cacerts

auth_provider = krb5
chpass_provider = krb5
krb5_realm = EXAMPLE.COM
krb5_canonicalize = False
krb5_validate = True
krb5_server = srv01.example.com,srv04.example.com,srv07.example.com
krb5_kpasswd = srv01.example.com

ldap_user_object_class = person
ldap_user_modify_timestamp = whenChanged
ldap_user_home_directory = unixHomeDirectory
ldap_user_shell = loginShell
ldap_user_principal = userPrincipalName
ldap_user_name = samAccountName
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber

ldap_group_object_class = group
ldap_group_modify_timestamp = whenChanged
ldap_group_name = samAccountName
ldap_group_gid_number = gidNumber

ldap_force_upper_case_realm = True
ldap_referrals = False

[sssd]
services = nss, pam
config_file_version = 2
domains = default

[nss]
filter_groups = root
filter_users = root

[pam]
pam_verbosity = 3

[sudo]

[autofs]

[ssh]
EOF

##-------------------------------------------------------------------------------------------------------------------------
# modifying cmb.conf
cat /etc/samba/smb.conf.orig | sed "s/workgroup = MYGROUP/workgroup = EXAMPLE\nnetbios name = $hostname\nsecurity = ads\ndedicated keytab file = \/etc\/krb5.keytab\nkerberos method = system keytab\nrealm = example.com/g" | sed 's/security = user//g' > /etc/samba/smb.conf

##-------------------------------------------------------------------------------------------------------------------------
echo "which user to join with? (*-adm accounts will set os-name and version)"
read username
echo "joining and setting os-name and version ..."
net ads join -U $username osname=`uname -s` osver=`uname -r`

net ads dns register -P

chmod 600 /etc/sssd/sssd.conf
service sssd start
chkconfig --add sssd 
service oddjobd start
chkconfig oddjobd on
authconfig --update --enablesssd --enablesssdauth
chkconfig sssd on

##-------------------------------------------------------------------------------------------------------------------------
cat /etc/nsswitch.conf.orig | sed 's/automount:  files/automount:  files ldap/g' > cat /etc/nsswitch.conf
echo "session     required      pam_oddjob_mkhomedir.so" >> /etc/pam.d/system-auth
echo "session     required      pam_oddjob_mkhomedir.so" >> /etc/pam.d/password-auth

clear
echo "config done - will reboot in 5 seconds"
sleep 5
reboot
