#!/bin/bash
set -eux


#
# configure apt.

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive
apt-get update


#
# disable IPv6.

cat>/etc/sysctl.d/98-disable-ipv6.conf<<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
systemctl restart procps
sed -i -E 's,(GRUB_CMDLINE_LINUX=.+)",\1 ipv6.disable=1",' /etc/default/grub
update-grub2


# TODO configure the firewall.


#
# provision vim.

apt-get install -y --no-install-recommends vim

cat>~/.vimrc<<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF


#
# configure the shell.

cat>~/.bash_history<<'EOF'
cat /etc/samba/smb.conf
cat /etc/default/bind9
journalctl
systemctl status
dig axfr example.com
EOF

cat>~/.bashrc<<'EOF'
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

export EDITOR=vim
export PAGER=less

alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat>~/.inputrc<<'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
set show-all-if-ambiguous on
set completion-ignore-case on
EOF
