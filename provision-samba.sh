#!/bin/bash
set -eux

export DEBIAN_FRONTEND=noninteractive

config_fqdn=$(hostname --fqdn)                                  # e.g. dc.example.com
config_realm=$(hostname --domain | tr a-z A-Z)                  # e.g. EXAMPLE.COM
config_domain=$(echo $config_realm | sed -E 's,([^.]+).+,\1,')  # NB this MUST be at most 15 characters. e.g. EXAMPLE
config_dns_resolver=$(systemd-resolve --status | awk '/DNS Servers: /{print $3}') # recurse queries through the default vagrant environment DNS server.
config_administrator_password=HeyH0Password

#
# install samba.
# see https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller
# see https://help.ubuntu.com/lts/serverguide/samba-dc.html.en
# see https://samba.tranquil.it/doc/en/samba_config_server/debian/server_install_samba_debian.html
#
# NB the answers were obtained (after installing krb5-config) with:
#
#   #sudo debconf-show krb5-config
#   sudo apt-get install debconf-utils
#   # this way you can see the comments:
#   sudo debconf-get-selections
#   # this way you can just see the values needed for debconf-set-selections:
#   sudo debconf-get-selections | grep -E '^krb5-config\s+' | sort

debconf-set-selections <<EOF
krb5-config krb5-config/default_realm string $config_realm
krb5-config krb5-config/kerberos_servers string
krb5-config krb5-config/admin_server string
EOF
apt-get install -y samba winbind libnss-winbind krb5-user smbclient ldb-tools

# configure kerberos.
cat >/etc/krb5.conf <<EOF
[libdefaults]
    default_realm = $config_realm
    dns_lookup_kdc = true
    dns_lookup_realm = false
EOF

# configure samba.
# NB since we are using a vagrant environment Samba should not listen on the default
#    NAT vagrant network, so we only bind the eth1 (and lo) interface.
rm -f /etc/samba/smb.conf
samba-tool domain provision \
    --realm=$config_realm \
    --domain=$config_domain \
    --site=$config_domain \
    --server-role=dc \
    --option='interfaces=lo eth1' \
    --option='bind interfaces only=yes'
samba-tool user setpassword administrator --newpassword=$config_administrator_password
rm -f /var/lib/samba/private/krb5.conf
ln -s /etc/krb5.conf /var/lib/samba/private/krb5.conf
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl stop winbind nmbd smbd
systemctl disable winbind nmbd smbd
systemctl mask winbind nmbd smbd


#
# install bind/named and configure samba to use it instead of the built-in dns server.
# see /var/lib/samba/private/named.txt
# see /var/lib/samba/private/named.conf

apt-get install -y bind9
cat >/etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";

    forwarders {
        $config_dns_resolver;
    };

    allow-query { any; };
    dnssec-validation no;

    auth-nxdomain no; # conform to RFC1035
    listen-on-v6 { any; };

    tkey-gssapi-keytab "/var/lib/samba/private/dns.keytab";
};
EOF
cat >/etc/bind/named.conf.local <<EOF
dlz "$config_realm" {
    database "dlopen /usr/lib/x86_64-linux-gnu/samba/bind9/dlz_bind9_11.so";
};
EOF
# tune apparmor to allow the loading of the samba artifacts.
# see http://manpages.ubuntu.com/manpages/bionic/en/man5/apparmor.d.5.html
# see http://manpages.ubuntu.com/manpages/bionic/en/man7/apparmor.7.html
# NB if something fails due to arparmor see the journalctl output; it will contain something like (look at the requested_mask to known what needs to be allowed):
#   Jun 13 12:12:18 dc named[738]: Loading 'EXAMPLE.COM' using driver dlopen
#   Jun 13 12:12:18 dc audit[738]: AVC apparmor="DENIED" operation="file_mmap" profile="/usr/sbin/named" name="/usr/lib/x86_64-linux-gnu/samba/bind9/dlz_bind9_11.so" pid=738 comm="isc-worker0000" requested_mask="m" denied_mask="m" fsuid=108 ouid=0
#   Jun 13 12:12:18 dc named[738]: dlz_dlopen failed to open library '/usr/lib/x86_64-linux-gnu/samba/bind9/dlz_bind9_11.so' - /usr/lib/x86_64-linux-gnu/samba/bind9/dlz_bind9_11.so: failed to map segment from shared object
cat >/etc/apparmor.d/local/usr.sbin.named <<'EOF'
/usr/lib/x86_64-linux-gnu/samba/**/*.so m,
/usr/lib/x86_64-linux-gnu/ldb/**/*.so m,
/var/lib/samba/private/dns/** rwk,
/var/lib/samba/private/dns.keytab rwk,
/dev/urandom rw,
EOF
systemctl reload apparmor
sed -i -E 's,^(\s*)#?(dns forwarder =.+),\1#\2\n\1server services = -dns,' /etc/samba/smb.conf
samba_upgradedns --dns-backend=BIND9_DLZ

# disable null session connections.
sed -i -E 's,^(\s*)#?(dns forwarder =.+),\1#\2\n\1restrict anonymous = 2,' /etc/samba/smb.conf
# disable NetBIOS.
sed -i -E 's,^(\s*)#?(dns forwarder =.+),\1#\2\n\1disable netbios = yes\n\1smb ports = 445,' /etc/samba/smb.conf
# disable printer support.
sed -i -E 's,^(\s*)#?(dns forwarder =.+),\1#\2\n\1printcap name = /dev/null\n\1load printers = no,' /etc/samba/smb.conf

# TODO configure a CA and the DC TLS certificate.

# disable systemd-resolved and switch to bind/named.
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm /etc/resolv.conf
cat >/etc/resolv.conf <<EOF
search $config_realm
nameserver 127.0.0.1
EOF

# only use IPv4.
sed -i -E 's,^(OPTIONS=).+,\1"-4 -u bind",' /etc/default/bind9

# restart the services.
systemctl restart bind9
systemctl restart samba-ad-dc

# add a reverve dns zone for our network and hosts.
# NB this zone is automatically managed by each computer as it boots.
# see https://wiki.samba.org/index.php/DNS_Administration
samba-tool dns zonecreate localhost 56.168.192.in-addr.arpa --username=Administrator%$config_administrator_password
samba-tool dns add localhost 56.168.192.in-addr.arpa 2 ptr dc.example.com --username=Administrator%$config_administrator_password

#
# install the NTP daemon and integrate it with samba.
# see https://wiki.samba.org/index.php/Time_Synchronisation
# see https://chrony.tuxfamily.org/doc/3.2/chrony.conf.html
# see https://chrony.tuxfamily.org/doc/3.2/chronyd.html
# see https://chrony.tuxfamily.org/doc/3.2/chronyc.html

# disable systemd-timesyncd so it doesn't try to sync the time.
# the time sync will be handled by chrony.
systemctl stop systemd-timesyncd
systemctl disable systemd-timesyncd

# install chrony.
apt-get install -y chrony

# only use IPv4.
# NB unfortunately this will not prevent some IPv6 warnings like:
#       chronyd[2361]: Could not open IPv6 NTP socket : Address family not supported by protocol
sed -i -E 's,^(DAEMON_OPTS=)"(.*)",\1"-4 \2",' /etc/default/chrony 

# integrate with samba.
cat >>/etc/chrony/chrony.conf <<EOF

# NB you might need to configure the upstream ntp server pool.

# allow all networks to access this chrony ntp server.
allow all

# let samba sign the MS-SNTP responses.
ntpsigndsocket /var/lib/samba/ntp_signd
EOF

# make sure chrony can access the samba socket directory (the socket file is
# created inside with permissions to everyone).
chgrp _chrony /var/lib/samba/ntp_signd

# restart chrony for it to pickup the changes.
systemctl restart chrony

# wait for it to sync.
chronyc waitsync

# try chrony.
chronyc tracking
chronyc sources
chronyc clients
chronyc serverstats

# try listing the smb shares.
# TODO figure out why this is failing to run from vagrant: session setup failed: NT_STATUS_INVALID_SID
smbclient --list=localhost --user=Administrator%$config_administrator_password || true

# try the DNS.
dig axfr $config_realm
dig dc.example.com
dig -x 192.168.56.2
