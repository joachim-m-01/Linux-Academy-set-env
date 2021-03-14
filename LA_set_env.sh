#! /bin/bash

prog=(vim bash-completion curl epel-release bind-utils firewalld)
debprog=(vim bash-completion curl bind-utils)
distro=$(grep "^ID=" /etc/os-release  | awk -F'=' '{print $2}' | tr -d '"')
logfile='/var/log/script.log'
sshfile='/etc/ssh/sshd_config'
sshauthfile="/home/${SUDO_USER}/.ssh/authorized_keys"
sshuser=$SUDO_USER
cloudfile='/etc/sudoers.d/90-cloud-init-users'
sshpubkey='PUBKEY GOES HERE'


# STDERR Goes here

exec 2> ${logfile}


# Need to be root

if [[ "$EUID" -ne "0" ]]; then
	echo 'Need to be root !'
	exit 1
fi


function debian {

	for i in ${debprog[*]}
	do
		if ! dpkg -L $i 2>/dev/null 1>&2; then
			echo "Install $i"
				/usr/bin/apt install $i 1> "$logfile" 1>&2
			echo "$i installed !"
		fi
	done

}
function redhat {

	for i in ${prog[*]}
	do
		if ! rpm -ql $i 2> /dev/null 1>&2; then
			/usr/bin/yum install -y $i 1> "$logfile" 1>&2
			echo "$i installed !"
		fi
	done

}
function autocomplete {

	cat <<-EOF | tee -a /etc/bashrc 1> $logfile
	if [[ -f /etc/bash_completion.d/redefine_filedir ]]; then
		. /etc/bash_completion.d/redefine_filedir
	fi
	EOF
}
function sshconfig {
	echo 'ssh configuration'
	echo -e '-----------------\n'
	if [[ -f $sshauthfile ]]; then
		echo "$sshpubkey" >>  $sshauthfile
	else
		mkdir /home/${sshuser}/.ssh/
		touch $sshauthfile && chown "${logname}:${logname}" $sshauthfile  && chmod 400 $sshauthfile
		echo "$sshpubkey" >  $sshauthfile
		chown -R ${sshuser}:${sshuser}  /home/${sshuser}/.ssh/
	fi


	cp $sshfile "${sshfile}".old
	sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' $sshfile

	cat <<- EOF | tee -a $sshfile 1> $logfile

	BANNER /etc/MOTD
	Match User $sshuser
		PasswordAuthentication yes
		PubkeyAuthentication yes
	EOF

	echo "This is a lab server don't loose your time trying to hack me" > /etc/MOTD
}
function bashalias {
	echo 'Adding aliases'
	echo -e '---------------\n'

	cat <<-EOF | tee -a /etc/bashrc
	alias ls="ls --color"
	alias ip="ip --color"
	alias ll="ls -l"
	alias lah="ls -lah"
	alias grep="grep --color"
	export EDITOR=/usr/bin/vim
	EOF
}
function usersudo {

	cat <<-EOF | tee -a /etc/sudoers.d/99-init-$(logname)
	$(logname) ALL=(ALL) NOPASSWD:ALL
	EOF
	if [[ -f $cloudfile ]]; then
		rm $cloudfile
	fi
}

echo '------------------------------'
echo 'Environnement configuration'
echo '------------------------------'

timedatectl set-timezone Europe/Paris
localectl set-locale LANG=fr_FR.UTF-8
localectl set-keymap fr
echo "syntax on" >> .vimrc
echo "set nu " >> .vimrc

	if [[ "$distro" = 'centos' ]]; then
		echo "This is a Centos version"
		redhat
		autocomplete
		sshconfig
		bashalias
		usersudo

	elif [[ "$distro" = 'rhel' ]]; then
		echo "This is a Redhat distro"
		redhat
		autocomplete
		sshconfig
		bashalias
		usersudo

	elif [[ "$distro" = 'debian' ]] || [[ "$distro" = 'ubuntu' ]]; then
		echo "This is a distro based on debian"
			debian
			sshconfig
	else
		echo "This script is not compatible with this distro"
		exit 1

	fi
