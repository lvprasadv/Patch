#!/bin/bash

bucketname=""
nessuskey="a521b5ff16a5d5272109d675bba8d84bd07e7126d686c1966ec8e1fce13abd16"
NessusGroup=gcp-oc-$(curl 'http://metadata.google.internal/computeMetadata/v1/project/attributes/cshortname' -H 'Metadata-Flavor: Google')


ls -ld /home/packages #Check if packages directory already exists

if [ $? -eq 0 ]; then
  echo "Packages directory already exists "
else
  echo "Creating packages directory for agents."
  sudo mkdir /home/packages
fi

cd /home/packages
#nessuskey=`gcloud secrets versions access latest --secret $nessus_secret --project $servicehub | cut -d : -f 2`

# Determine OS type first. This script is designed only to run on SuSE, CentOS, Red Hat and Ubuntu
/*if grep -qi suse /etc/os-release; then
  var="SUSE"
  echo $var
elif [ -f /etc/redhat-release ]; then
  distribution=$(cat /etc/redhat-release )
  var=`echo $distribution | awk 'NR==1{print $1}'`
  echo $var
elif [ -f /etc/centos-release ]; then
  distribution=$(cat /etc/centos-release )
  var=`echo $distribution | awk 'NR==1{print $1}'`
  echo $var
else
  distribution=$(lsb_release -i | grep 'ID')
  var=`echo $distribution | awk -F ": " '{print $2}'`
  echo $var
fi
*/
#Install agents for Centos OS
if [ "$var" = "CentOS" ]; then
echo "CentOS"
STATUS="$(systemctl is-active nessusagent.service)" 

if [ "${STATUS}" = "active" ]; then

    service nessusagent status | grep "active (running)"
    if [ $? -eq 0 ]
	then
  	echo "Nessus Agent is Installed, State is running - Link Status Check Required "
  	exit 1
    else
  	echo "Nessus Agent is Installed, State is stopped - Starting of the Agent and Link Status Check Required."
	service nessusagent start
	echo "Checking Agent Status and Linking Status..."
	service nessusagent status | grep "running"
         if [ $? -eq 0 ]
             then
              /opt/nessus_agent/sbin/nessuscli agent status | grep error
  	      agentLinkStatus=$(echo $?)
              /opt/nessus_agent/sbin/nessuscli agent status | grep warn
              agentLinkStatusWarn=$(echo $?)
              if [ $agentLinkStatusWarn -eq "0" ] || [ $agentLinkStatus -eq "0" ]
              then
               echo "Nessus Agent is not linked properly."
               exit 1
              else
              echo "Nessus Agent is Linked properly."
              exit 0
              fi
  	      exit 0
	      fi
       echo "Error during Nessus Agent Installation - Manual Intervention Needed"
     exit 1
 fi
    
    else [ "${STATUS}" = "inactive" ]; then
    
       echo "*********************Start Nessus agent servcie*************************"
       sudo /bin/systemctl start nessusagent.service
    
      gsutil cp gs://$bucketname/NessusAgent-8.3.1-es7.x86_64.rpm /home/packages
      echo "downloaded rpm package" > DownloadedRPMPackage
      rpm -ivh NessusAgent-8.3.1-es7.x86_64.rpm
      echo "**************Nessus agent is installed successfully ***************************"
      /opt/nessus_agent/sbin/nessuscli agent link --host=cloud.tenable.com --port=443 --key=$nessuskey --groups="'$NessusGroup'"
      echo "Linked successfully" > LinkedNessus
      sudo /bin/systemctl start nessusagent.service
      sudo /bin/systemctl status nessusagent.service
    fi
  fi

  if [[ "$trendmicro" == "true" ]]; then
    # Install dos2unix to remove special characters found in installation file
    sudo /bin/systemctl status ds_agent.service #Check if Trend Micro agent is running
    if [ $? -eq 0 ]; then
      echo "----------------------------------------------------------------------------------------------------"
      echo "*******************Trend Micro agent is already running. Installation skipped **********************"
      echo "----------------------------------------------------------------------------------------------------"
      sudo bash AgentDeploymentScript.sh $trend_policy_id
    else
      echo "Started Trendmicro"
      yum -y install dos2unix
      gsutil cp gs://$bucketname/AgentDeploymentScript.sh /home/packages
      dos2unix AgentDeploymentScript.sh
      sleep 5s
      sudo bash AgentDeploymentScript.sh $trend_policy_id

      if [ $? -eq 0 ]; then
        echo "**************TrendMicro agent is installed successfully ***************************"
      else
        echo "**************TrendMicro agent failed installation ***************************"
      fi
      sleep 30s
    fi
  else
    echo "Trendmicro label is set false for the project or the VM, skipping agent installation"
  fi

  if [[ "$scaleft" == "true" ]]; then
    sudo /bin/systemctl status sftd
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Okta ASA agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      gcloud secrets versions access latest --secret asa_enrollment_token_linux
      if [ $? -eq 0 ]; then
        mkdir -p /var/lib/sftd
        gcloud secrets versions access latest --secret asa_enrollment_token_linux > /var/lib/sftd/enrollment.token
      fi
      curl -C - https://pkg.scaleft.com/scaleft_yum.repo | sudo tee /etc/yum.repos.d/scaleft.repo
      rpm --import https://dist.scaleft.com/pki/scaleft_rpm_key.asc
      yum install scaleft-server-tools -y
      echo "**************Okta ASA agent is installed successfully ***************************"
    fi
  else
    echo "Okta ASA label is not set to true. Installation skipped."
  fi


#Install agents for Ubuntu OS
elif [ "$var" = "Ubuntu" ]; then
  echo "UbuntuOS"
  sudo apt-get update
  sleep 5s
  sudo apt-get install dos2unix -y
  sleep 5s
  if [[ "$nessus" == "true" ]]; then
    sudo /etc/init.d/nessusagent status #Check if Nessus agent is running
    if [ $? -eq 0 ]; then
      echo "----------------------------------------------------------------------------------------------------"
      echo "*****************************Nessus agent is already running. Installation skipped *****************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      gsutil cp gs://$bucketname/NessusAgent-8.3.1-ubuntu1110_amd64.deb /home/packages
      echo "downloaded Nessus DEB package" > DownloadedDEBPackage
      sudo dpkg -i NessusAgent-8.3.1-ubuntu1110_amd64.deb
      echo "**************Nessus agent is installed successfully ***************************"
      /opt/nessus_agent/sbin/nessuscli agent link --host=cloud.tenable.com --port=443 --key=$nessuskey --groups="'$NessusGroup'"
      echo "Linked successfully"
      sudo /etc/init.d/nessusagent start
    fi
  else
    echo "Nessus label is set false for the project or the VM, skipping agent installation"
  fi

  if [[ "$trendmicro" == "true" ]]; then
    # Install dos2unix to remove special characters found in installation file
    sudo /etc/init.d/ds_agent status #Check if Trend Micro agent is running
    if [ $? -eq 0 ]; then
      echo "----------------------------------------------------------------------------------------------------"
      echo "*******************Trend Micro agent is already running. Installation skipped **********************"
      echo "----------------------------------------------------------------------------------------------------"
      sudo bash AgentDeploymentScript.sh $trend_policy_id
    else
      echo "Started Trendmicro Installation" > trendmicrostarted
      gsutil cp gs://$bucketname/AgentDeploymentScript.sh /home/packages
      dos2unix AgentDeploymentScript.sh
      sleep 5s

      sudo bash AgentDeploymentScript.sh $trend_policy_id
      if [ $? -eq 0 ]; then
        echo "**************TrendMicro agent is installed successfully ***************************"
      else
        echo "**************TrendMicro agent failed installation ***************************"
      fi
      sleep 30s
    fi
  else
    echo "Trendmicro label is set false for the project or the VM, skipping agent installation"
  fi

  sudo /etc/init.d/google-fluentd status
	if [ $? -eq 0 ]; then
    echo "---------------------------------------------------------------------------------------------------"
    echo "**************Stackdriver logging agent is already running. Installation skipped ***************************"
    echo "----------------------------------------------------------------------------------------------------"
	else
    curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
    sudo bash install-logging-agent.sh
    echo "**************Stackdriver logging agent is installed successfully ***************************"
    sleep 30s
	fi

  if [[ "$monitoring" == "true" ]]; then
    sudo /bin/systemctl status stackdriver-agent
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Stackdriver monitoring agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
      sudo bash install-monitoring-agent.sh
      echo "**************Stackdriver monitoring agent is installed successfully ***************************"
      sleep 5s
    fi
  else
    echo "Enable Stackdriver monitoring label is set to false. Installation skipped"
  fi

  if [[ "$scaleft" == "true" ]]; then
    sudo /bin/systemctl status sftd
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Okta ASA agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      gcloud secrets versions access latest --secret asa_enrollment_token_linux
      if [ $? -eq 0 ]; then
        mkdir -p /var/lib/sftd
        gcloud secrets versions access latest --secret asa_enrollment_token_linux > /var/lib/sftd/enrollment.token
      fi
      echo "deb http://pkg.scaleft.com/deb linux main" | sudo tee -a /etc/apt/sources.list
      curl -C - https://dist.scaleft.com/pki/scaleft_deb_key.asc | sudo apt-key add -
      sudo apt-get update && sudo apt-get install scaleft-server-tools -y
      echo "**************Okta ASA agent is installed successfully ***************************"
    fi
  else
    echo "Okta ASA label is not set to true. Installation skipped."
  fi

  sudo systemctl restart ntp.service
  nolines=$(ntpq -p | wc -l)

  if [[ nolines -gt 3 ]]; then
    sudo sed $ntpdeleteafterline,$(($ntpdeleteafterline+2))'d' /etc/ntp.conf
    sudo systemctl restart ntp.service
    sudo ntpq -p
    echo "*************NTP server set to Google metadata server ***************************"
  else
    echo "*************NTP configuration file doesn't need to be changed***************************"
  fi
#Install agents for RedHat OS
elif [[ "$var" = "Red" || "$var" = "RedHatEnterpriseServer" ]]; then
  echo "RedHatEnterpriseServer"
  if [[ "$nessus" == "true" ]]; then
    sudo /bin/systemctl status nessusagent.service #Check if Nessus agent is running
    if [ $? -eq 0 ]; then
      echo "----------------------------------------------------------------------------------------------------"
      echo "*****************************Nessus agent is already running. Installation skipped *****************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      gsutil cp gs://$bucketname/NessusAgent-8.3.1-es7.x86_64.rpm /home/packages
      echo "downloaded rpm package"
      yum -y install NessusAgent-8.3.1-es7.x86_64.rpm
      echo "**************Nessus agent is installed successfully ***************************"
      echo $NessusGroup
      /opt/nessus_agent/sbin/nessuscli agent link --host=cloud.tenable.com --port=443 --key=$nessuskey --groups="'$NessusGroup'"
      echo "Nessus Linked successfully"
      sudo /bin/systemctl start nessusagent.service
    fi
  else
    echo "Nessus label is set false for the project or the VM, skipping agent installation"
  fi

  if [[ "$trendmicro" == "true" ]]; then
    # Install dos2unix to remove special characters found in installation file
    sudo /bin/systemctl status ds_agent.service #Check if Trend Micro agent is running
    if [ $? -eq 0 ]; then
      echo "----------------------------------------------------------------------------------------------------"
      echo "*******************Trend Micro agent is already running. Installation skipped **********************"
      echo "----------------------------------------------------------------------------------------------------"
      sudo bash AgentDeploymentScript.sh $trend_policy_id
    else
      echo "Started Trendmicro Installation" > trendmicrostarted
      yum -y install dos2unix
      gsutil cp gs://$bucketname/AgentDeploymentScript.sh /home/packages
      dos2unix AgentDeploymentScript.sh
      sleep 5s
      sudo bash AgentDeploymentScript.sh $trend_policy_id
      echo "**************TrendMicro agent is installed successfully ***************************"
      sleep 30s
      sudo /bin/systemctl status ds_agent.service | grep -i active
      if [ $? -eq 0 ]; then
        echo "**************TrendMicro agent is installed successfully ***************************"
      else
        echo "**************TrendMicro agent failed installation ***************************"
      fi
    fi
  else
    echo "Trendmicro label is set false for the project or the VM, skipping agent installation"
  fi

	sudo /bin/systemctl status google-fluentd.service
	if [ $? -eq 0 ]; then
    echo "---------------------------------------------------------------------------------------------------"
    echo "**************Stackdriver logging agent is already running. Installation skipped ***************************"
    echo "----------------------------------------------------------------------------------------------------"
	else
    curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
    sudo bash install-logging-agent.sh
    sleep 30s
    echo "**************Stackdriver logging agent is installed successfully ***************************"
	fi

  if [[ "$monitoring" == "true" ]]; then
    sudo /bin/systemctl status stackdriver-agent
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Stackdriver monitoring agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
      sudo bash install-monitoring-agent.sh
      echo "**************Stackdriver monitoring agent is installed successfully ***************************"
      sleep 5s
    fi
  else
    echo "Enable Stackdriver monitoring label is set to false. Installation skipped"
  fi

  if [[ "$scaleft" == "true" ]]; then
    sudo /bin/systemctl status sftd
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Okta ASA agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      gcloud secrets versions access latest --secret asa_enrollment_token_linux
      if [ $? -eq 0 ]; then
        mkdir -p /var/lib/sftd
        gcloud secrets versions access latest --secret asa_enrollment_token_linux > /var/lib/sftd/enrollment.token
      fi
      curl -C - https://pkg.scaleft.com/scaleft_yum.repo | sudo tee /etc/yum.repos.d/scaleft.repo
      rpm --import https://dist.scaleft.com/pki/scaleft_rpm_key.asc
      yum install scaleft-server-tools -y
      echo "**************Okta ASA agent is installed successfully ***************************"
    fi
  else
    echo "Okta ASA label is not set to true. Installation skipped."
  fi

  sudo service ntpd restart
  nolines=$(ntpq -p | wc -l)
  if [[ nolines -gt 3 ]]; then
    sudo sed $ntpdeleteafterline,$(($ntpdeleteafterline+2))'d' /etc/ntp.conf
    sudo service ntpd restart
    sudo ntpq -p
    echo "*************NTP server set to Google metadata server ***************************"
  else
    echo "*************NTP configuration file doesn't need to be changed***************************"
  fi
elif [ "$var" = "SUSE" ]; then
  echo "SUSE"
  echo "$USER"
  if [[ "$nessus" == "true" ]]; then
    sudo /bin/systemctl status nessusagent.service #Check if Nessus agent is running
    if [ $? -eq 0 ]; then
      echo "----------------------------------------------------------------------------------------------------"
      echo "*********************Nessus agent is already running. Installation skipped *************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      /usr/bin/google-cloud-sdk/bin/gsutil cp gs://$bucketname/NessusAgent-8.3.1-es7.x86_64.rpm /home/packages
      rpm -ivh NessusAgent-8.3.1-es7.x86_64.rpm
      /opt/nessus_agent/sbin/nessuscli agent link --host=cloud.tenable.com --port=443 --key=$nessuskey --groups="'$NessusGroup'"
      sudo /bin/systemctl start nessusagent.service
    fi
  else
    echo "Nessus label is set false for the project or the VM, skipping agent installation"
  fi

  if [[ "$trendmicro" == "true" ]]; then
    # Install dos2unix to remove special characters found in installation file
    sudo /bin/systemctl status ds_agent.service #Check if Trend Micro agent is running
    if [ $? -eq 0 ]; then
      echo "-----------------------------------------------------------------------------------------------------"
      echo "*******************Trend Micro agent is already running. Installation skipped **********************"
      echo "----------------------------------------------------------------------------------------------------"
      sudo bash AgentDeploymentScript.sh $trend_policy_id
    else
      echo "Started Trendmicro"
      /usr/bin/google-cloud-sdk/bin/gsutil cp gs://$bucketname/dos2unix-7.4.0-88.1.src.rpm /home/packages
      rpm -ivh dos2unix-7.4.0-88.1.src.rpm
      /usr/bin/google-cloud-sdk/bin/gsutil cp gs://$bucketname/AgentDeploymentScript.sh /home/packages
      dos2unix AgentDeploymentScript.sh
      sudo bash AgentDeploymentScript.sh $trend_policy_id
      sleep 4s
    fi
  else
    echo "Trendmicro label is set false for the project or the VM, skipping agent installation"
  fi

  sudo systemctl status google-fluentd.service
  if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Stackdriver Logging agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
  else
      /usr/bin/curl -s https://dl.google.com/cloudagents/install-logging-agent.sh | sudo bash
  fi

  if [[ "$monitoring" == "true" ]]; then
    sudo systemctl status stackdriver-agent.service
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Stackdriver Monitoring agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      /usr/bin/curl -s https://dl.google.com/cloudagents/install-monitoring-agent.sh | sudo bash
      echo "**************Stackdriver monitoring agent is installed successfully ***************************"
      sleep 5s
    fi
  else
    echo "Enable Stackdriver monitoring label is set to false. Installation skipped"
  fi

  if [[ "$scaleft" == "true" ]]; then
    sudo systemctl status sftd
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Okta ASA agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      /usr/bin/google-cloud-sdk/bin/gcloud secrets versions access latest --secret asa_enrollment_token_linux
      if [ $? -eq 0 ]; then
        mkdir /var/lib/sftd
        /usr/bin/google-cloud-sdk/bin/gcloud secrets versions access latest --secret asa_enrollment_token_linux > /var/lib/sftd/enrollment.token
      fi
      curl -C - https://pkg.scaleft.com/scaleft_yum.repo | sudo tee /etc/zypp/repos.d/scaleft.repo
      rpm --import https://dist.scaleft.com/pki/scaleft_rpm_key.asc
      zypper --non-interactive install scaleft-server-tools
      echo "**************Okta ASA agent is installed successfully ***************************"
    fi
  else
    echo "Okta ASA label is not set to true. Installation skipped."
  fi

  sudo systemctl restart ntpd.service
  nolines=$(ntpq -p | wc -l)
  if [[ nolines -gt 3 ]]; then
    sudo sed $ntpdeleteafterline,$(($ntpdeleteafterline+2))'d' /etc/ntp.conf
    sudo systemctl restart ntpd.service
    sudo ntpq -p
    echo "*************NTP server set to Google metadata server ***************************"
  else
    echo "*************NTP configuration file doesn't need to be changed***************************"
  fi
elif [ "$var" = "Debian" ]; then
  echo "Debian OS"
  sudo apt-get update
  sleep 5s
  sudo apt-get upgrade dos2unix -y
  sleep 5s
  if [[ "$nessus" == "true" ]]; then
    sudo /etc/init.d/nessusagent status #Check if Nessus agent is running
    if [ $? -eq 0 ]; then
      echo "----------------------------------------------------------------------------------------------------"
      echo "*****************************Nessus agent is already running. Installation skipped *****************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      gsutil cp gs://$bucketname/NessusAgent-8.3.1-debian6_amd64.deb /home/packages
      echo "downloaded Nessus DEB package" > DownloadedDEBPackage
      sudo dpkg -i NessusAgent-8.3.1-debian6_amd64.deb
      echo "**************Nessus agent is installed successfully ***************************"
      /opt/nessus_agent/sbin/nessuscli agent link --host=cloud.tenable.com --port=443 --key=$nessuskey --groups="'$NessusGroup'"
      echo "Linked successfully"
      sudo /etc/init.d/nessusagent start
    fi
  else
    echo "Nessus label is set false for the project or the VM, skipping agent installation"
  fi

  if [[ "$trendmicro" == "true" ]]; then
    # Install dos2unix to remove special characters found in installation file
    sudo /etc/init.d/ds_agent status #Check if Trend Micro agent is running
    if [ $? -eq 0 ]; then
      echo "----------------------------------------------------------------------------------------------------"
      echo "*******************Trend Micro agent is already running. Installation skipped **********************"
      echo "----------------------------------------------------------------------------------------------------"
      sudo bash AgentDeploymentScript.sh $trend_policy_id
    else
      echo "Started Trendmicro Installation" > trendmicrostarted
      gsutil cp gs://$bucketname/AgentDeploymentScript.sh /home/packages
      dos2unix AgentDeploymentScript.sh
      sleep 5s

      sudo bash AgentDeploymentScript.sh $trend_policy_id
      if [ $? -eq 0 ]; then
        echo "**************TrendMicro agent is installed successfully ***************************"
      else
        echo "**************TrendMicro agent failed installation ***************************"
      fi
      sleep 30s
    fi
  else
    echo "Trendmicro label is set false for the project or the VM, skipping agent installation"
  fi

  sudo /etc/init.d/google-fluentd status
	if [ $? -eq 0 ]; then
    echo "---------------------------------------------------------------------------------------------------"
    echo "**************Stackdriver logging agent is already running. Installation skipped ***************************"
    echo "----------------------------------------------------------------------------------------------------"
	else
    curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
    sudo bash install-logging-agent.sh
    echo "**************Stackdriver logging agent is installed successfully ***************************"
    sleep 30s
	fi

  if [[ "$monitoring" == "true" ]]; then
    sudo /bin/systemctl status stackdriver-agent
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Stackdriver monitoring agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
      sudo bash install-monitoring-agent.sh
      echo "**************Stackdriver monitoring agent is installed successfully ***************************"
      sleep 5s
    fi
  else
    echo "Enable Stackdriver monitoring label is set to false. Installation skipped"
  fi

  if [[ "$scaleft" == "true" ]]; then
    sudo /bin/systemctl status sftd
    if [ $? -eq 0 ]; then
      echo "---------------------------------------------------------------------------------------------------"
      echo "**************Okta ASA agent is already running. Installation skipped ***************************"
      echo "----------------------------------------------------------------------------------------------------"
    else
      gcloud secrets versions access latest --secret asa_enrollment_token_linux
      if [ $? -eq 0 ]; then
        mkdir -p /var/lib/sftd
        gcloud secrets versions access latest --secret asa_enrollment_token_linux > /var/lib/sftd/enrollment.token
      fi
      echo "deb http://pkg.scaleft.com/deb linux main" | sudo tee -a /etc/apt/sources.list
      curl -C - https://dist.scaleft.com/pki/scaleft_deb_key.asc | sudo apt-key add -
      sudo apt-get update && sudo apt-get install scaleft-server-tools -y
      echo "**************Okta ASA agent is installed successfully ***************************"
    fi
  else
    echo "Okta ASA label is not set to true. Installation skipped."
  fi

  sudo systemctl restart ntp.service
  nolines=$(ntpq -p | wc -l)
  if [[ nolines -gt 3 ]]; then
    sudo sed $ntpdeleteafterline,$(($ntpdeleteafterline+2))'d' /etc/ntp.conf
    sudo systemctl restart ntp.service
    sudo ntpq -p
    echo "*************NTP server set to Google metadata server ***************************"
  else
    echo "*************NTP configuration file doesn't need to be changed***************************"
  fi
else
    echo "Unsupported Operating System";
fi
