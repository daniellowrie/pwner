#!/bin/bash

shellit='xterm -iconic -e /bin/bash -l -c '
termy='terminator -x "/bin/bash -l -c '

portScan() {
times=$(date | awk '{print $5,$6,$7}')
echo "[*]"
echo "[*] Port Scan $times"
echo "[*] **********************************************" 
for t in $targets
do
	echo -e "[*] Finding open ports for target: \033[0;32m$t\033[0m"
	nmap -T4 -n -Pn -p- $t -o nmap_all_$t.txt 1>/dev/null
	echo "[*] Done!"
	ports=$(sed 's,\/, ,g' nmap_all_$t.txt | grep -e "^[0-9]" | sed 's/tcp//g' | awk '{print $1}' | sed -z 's/\n/\,/g' | sed 's/.$/ /')
	echo "[*]"
	echo "[*]"
	if [[ $ports == "" ]]
	then
		echo "[!] No open ports found. Cannot perform version scan!"
		echo "[*]"
		echo "[*]"
	else
		echo -e "[!] Getting version for ports: \033[0;32m$ports\033[0mfor Target: \033[0;32m$t\033[0m"
		nmap -A -T4 -n -Pn -p $ports $t -o nmap_deep_$t.txt 1>/dev/null
		echo "[*] Done!"
		echo "[*]"
		echo "[*]"
	fi
done
webCheck
}

webCheck() {

www_targets=""

for t in $targets
do
	echo -e "[*] Checking \033[0;32m$t\033[0m for Web Services"
	echo "[*] **********************************************" 
	webServers=$(grep -E 'http|httpd|https|Apache|nginx|IIS' nmap_deep_$t.txt | grep -e "^[0-9]"| sed 's/\/tcp//g' | awk '{print $1}' | sed -z 's/\n/ /g' | sed 's/.$/ /')
	if [[ "$webServers" == "" ]]
	then
		echo "[!] No Web Services Found!"
		echo "[*]"
	else
		echo "[!] Found Web Services"
		echo "[*]"
		www_targets="$www_targets$t "
	fi
done
webEnum
}

webEnum() {

for t in $www_targets
do
	echo -e "[*] Fuzzing \033[0;32m$t\033[0m for web directories and vulnerabilities"
	echo "[*]"
	webServers=$(grep -E 'http|httpd|https|Apache|nginx|IIS' nmap_deep_$t.txt | grep -e "^[0-9]"| sed 's/\/tcp//g' | awk '{print $1}' | sed -z 's/\n/ /g' | sed 's/.$/ /')
	for w in $webServers
	do
		if [[ "$w" == "80" ]]
		then
			#/bin/bash echo 'n\r' | nikto -h http://$t -o nikto_$t.txt
			$shellit "echo 'n\r' | nikto -h http://$t -o nikto_$t.txt" &
			$shellit "gobuster dir -u http://$t -w /usr/share/wordlists/dirmaster.txt -x php,txt,html -o gobuster_dirmaster.txt" &
			#$shellit "gobuster dir -u http://$t -w /usr/share/wordlists/dirmaster2.txt -x php,txt,html -o gobuster_dirmaster2.txt" &
			#$shellit "gobuster dir -u http://$t -w /usr/share/wordlists/alldirb.txt -x php,txt,html -o gobuster_alldirb.txt" &
			#$shellit "gobuster dir -u http://$t -w /usr/share/wordlists/dm1.txt -x php,txt,html -o gobuster_dm1.txt" &
			#$shellit "gobuster dir -u http://$t -w /usr/share/wordlists/dm2.txt -x php,txt,html -o gobuster_dm2_$w.txt" &
		else
			$shellit "echo 'n\r' | nikto -h http://$t:$w -o nikto_$t_$w.txt" &
			$shellit "gobuster dir -u http://$t:$w -w /usr/share/wordlists/alldirb.txt -x php,txt,html -o gobuster_alldirb_$w.txt" &
			#$shellit "gobuster dir -u http://$t:$w -w /usr/share/wordlists/dm1.txt -x php,txt,html -o gobuster_dm1_$w.txt" &
			#$shellit "gobuster dir -u http://$t:$w -w /usr/share/wordlists/dm2.txt -x php,txt,html -o gobuster_dm2_$w.txt" &
		fi
	done
done
smbEnum
}

smbEnum(){
echo "[*]"
for t in $targets
do
	echo -e "[*] Checking \033[0;32m$t\033[0m for SMB"
	echo "[*] **********************************************"
	smbServers=$(grep -E 'netbios|samba|Samba|smbd' nmap_deep_$t.txt | grep -e "^[0-9]"| sed 's/\/tcp//g' | awk '{print $1}' | sed -z 's/\n/ /g' | sed 's/.$/ /')
		if [[ "$smbServers" == "" ]]
		then
			echo "[*] No SMB services found"
			echo "[*]"
			echo "[*]"
		else
			echo -e "[*] SMB Shares on \033[0;32m$t\033[0m"
			echo "[*] **********************************************"
			smbclient --user=test -N --list=$t
			echo "[*]"
			echo -e "[*] Detailed SMB scan on \033[0;32m$t\033[0m (this may take some time)"
			echo "[*] **********************************************"
			$shellit "enum4linux -a $t > enum4linux_$t.txt" &
			echo "[*]"
			echo "[*]"

		fi
done
times=$(date | awk '{print $5,$6,$7}')
echo "[*] Done! $times"
echo "[*] Now go root some boxes!"
}



main() {
clear
echo "    **********************************************"
echo "    ******             Pwn3r!               ******"
echo "    **********************************************"
echo ""
read -p "[*] Enter target: " target

var1=0
targets=""

hosts=$(nmap -sn -T4 -n $target | grep "Nmap scan report" | cut -d " " -f 5)

until [ "$var1" != "0" ]
do
	for i in $hosts
	do
		read -p "$(echo -e '[?] Add to list of hosts to scan? \033[0;32m'$i'\033[0m (y/n) ')" scan
		if [[ $scan == "" ]]
		then
			targs="${targets} $i"
			targets=$targs	
		else
			case $scan in
				y|Y|yes|Yes|YES)	targs="${targets} $i"
							targets=$targs ;;
				n|N|no|No|NO)		echo "[*] Moving on then" ;;
				*)			echo "[!] Invalid" ;;
			esac
		fi
	done
	((var1++))
done
portScan
}

main

