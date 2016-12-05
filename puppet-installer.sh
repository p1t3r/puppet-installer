#!/bin/bash

###################################################################
#####                                                         #####
##### Puppet master installation and configuration - CentOS 7 #####
#####                                                         #####
###################################################################


#################################
### Check system requirements ###
#################################

# Check whether script has been started as a root/sudo.
if [ $EUID -ne 0 ]
then
	printf "You have to run this script as a root/sudo.\n" &&
	exit 1
# Check whether we run on CentOS 7
elif [ $(grep -c "CentOS Linux release 7" /etc/system-release) -eq 0 ]
then
        printf "\n##### Sorry, this script works only on CentOS 7 #####\n\n"
        exit 1
# Check whether all arguments has been provided for us on the command line.
elif [ $# -eq 0 ]
then
	printf "Usage: $0 <domain to autosign>\n"
	exit 1
else
	OUR_DOMAIN=$1
	clear
	printf "\n##### Puppet master installation and configuration #####\n\n"
        sleep 2
fi


###########################
### Deactivate firewall ###
###########################

printf "\nDeactivating firewall\n"
sleep 1

# Stop firewall.
if [ "$(systemctl is-active firewalld.service)" == "active" ]
then
	if ! systemctl stop firewalld.service &> /dev/null
	then
		printf "Could not stop firewall. Exiting..\n"
		exit 1
	fi
fi

# Disable firewall.
if [ "$(systemctl is-enabled firewalld.service)" == "enabled" ]
then
	if ! systemctl disable firewalld.service &> /dev/null
	then
		printf "Could not disable firewall. Exiting..\n"
		exit 1
	fi
fi


##########################################################
### Switching temporarily SELinux into permissive mode ###
##########################################################

printf "\nSwitching SELinux into permissive mode\n"
sleep 1

if [ "$(getenforce)" == "Enforcing" ]
then
	if ! setenforce 0 &> /dev/null
	then
		printf "Could not switch SELinux into permissive mode. Exiting..\n"
		exit 1
	fi
fi


#########################################################################
### If puppet agent is currently running we will stop and disable it. ###
#########################################################################

printf "\nDeactivating puppet agent\n"
sleep 1

# Stop puppet agent.
if [ "$(systemctl is-active puppet.service)" == "active" ]
then
	if ! systemctl stop puppet.service &> /dev/null
	then
		printf "Could not stop puppet agent. Exiting..\n"
		exit 1
	fi
fi

# Disable puppet agent.
if [ "$(systemctl is-enabled puppet.service)" == "enabled" ]
then
	if ! systemctl disable puppet.service &> /dev/null
	then
		printf "Could not disable puppet agent. Exiting..\n"
		exit 1
	fi
fi


##############################################
### Prepare puppet server from Puppet Labs ###
##############################################

printf "\nPreparing puppet server\n"
sleep 1

# Check if Puppet Labs Repository is already installed
if [ "$(yum repolist | grep -c puppetlabs-products)" -eq 0 ] 
then
	# Install Puppet Labs repo.
	if ! rpm -ivh https://yum.puppetlabs.com/el/7/products/x86_64/puppetlabs-release-7-11.noarch.rpm &> /dev/null
	then
		printf "Could not install Puppet Labs repositories. Exiting..\n"
		exit 1
	fi
fi

# Install puppet server.
if ! rpm -q puppet-server.noarch &> /dev/null
then
	if ! yum install -y puppet-server.noarch &> /dev/null
	then
		printf "Could not install puppet server. Exiting..\n"
		exit 1
	fi
fi

# Enable puppet master on system start.
if [ "$(systemctl is-enabled puppetmaster.service)" != "enabled" ]
then
	if ! systemctl enable puppetmaster.service &> /dev/null
	then
		printf "Could not enable puppet server. Exiting..\n"
		exit 1
	fi
fi

# Start puppet master.
if [ "$(systemctl is-active puppetmaster.service)" != "active" ]
then
	if ! systemctl start puppetmaster.service &> /dev/null
	then
		printf "Could not start puppet server. Exiting..\n"
		exit 1
	fi
fi

# Prepare configuration file "/etc/puppet/puppet.conf"
if [ $(grep -c "autosign =" /etc/puppet/puppet.conf) -eq 0 ]
then
	if ! printf "[master]\n\t# Autosign certificates in whitelist\n\tautosign = \$confdir/autosign.conf\n" >> /etc/puppet/puppet.conf
	then
		printf "Could not write to \"/etc/puppet/puppet.conf\". Exiting..\n"
		exit 1
	fi
fi

# Prepare configuration file "/etc/puppet/autosign.conf"
if [ ! -f /etc/puppet/autosign.conf ]
then
	if ! printf "*.$OUR_DOMAIN\n" >> /etc/puppet/autosign.conf
	then
		printf "Could not write to \"/etc/puppet/autosign.conf\". Exiting..\n"
		exit 1
	fi
fi

# Restart puppet master to re-read the configuration - reload is not applicable for unit puppetmaster.service.
if ! systemctl restart puppetmaster.service &> /dev/null
then
	printf "Could not restart puppet server. Exiting..\n"
	exit 1
fi


### Install additional software ###

printf "Install additional software\n"
if ! yum install -y httpd httpd-devel mod_ssl ruby-devel rubygems gcc-c++ curl-devel zlib-devel make automake openssl-devel &> /dev/null
then
	printf "Could not install additional software. Exiting..\n"
	exit 1
fi

# Install Phusion Passenger Repository
if ! curl --fail -sSLo /etc/yum.repos.d/passenger.repo https://oss-binaries.phusionpassenger.com/yum/definitions/el-passenger.repo &> /dev/null
then
	printf "Could not install Phusion Passenger respository. Exiting..\n"
	exit 1
fi

# Install Passenger and Apache module
if ! yum install -y mod_passenger &> /dev/null
then
	printf "Could not install Passnger and its Apache module. Exiting..\n"
	exit 1
fi

### Prepare httpd ###
# Enable httpd
if ! systemctl enable httpd &> /dev/null
then
	printf "Could not enable httpd server. Exiting..\n"
	exit 1
fi
# Enable httpd
if ! systemctl start httpd &> /dev/null
then
	printf "Could not start httpd server. Exiting..\n"
	exit 1
fi
