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
#STATUS="$(systemctl is-active nessusagent.service)" 

if [ "$(systemctl is-active nessusagent.service)" = "active" ]; 
 then

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
              echo "Nessus Agent is not linked properly. Linking the agent"
	            /opt/nessus_agent/sbin/nessuscli agent link --host=cloud.tenable.com --port=443 --key=$nessuskey --groups="'$NessusGroup'"
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
    
  else [ "$(systemctl is-active nessusagent.service)" = "inactive" ]; then
    
      echo "*********************Start Nessus agent servcie*************************"
      sudo /bin/systemctl start nessusagent.service
      service nessusagent status | grep "running"
        if [ $? -eq 0 ]
         then
            /opt/nessus_agent/sbin/nessuscli agent status | grep error
  	        agentLinkStatus=$(echo $?)
            /opt/nessus_agent/sbin/nessuscli agent status | grep warn
            agentLinkStatusWarn=$(echo $?)
            if [ $agentLinkStatusWarn -eq "0" ] || [ $agentLinkStatus -eq "0" ]
             then
              echo "Nessus Agent is not linked properly. Linking the agent"
	            /opt/nessus_agent/sbin/nessuscli agent link --host=cloud.tenable.com --port=443 --key=$nessuskey --groups="'$NessusGroup'"
              exit 1
             else
              echo "Nessus Agent is Linked properly."
              exit 0
            fi
         fi
 fi

#uninstall nessusagent and reinstall
if [[ "$(systemctl is-active nessusagent.service)" = "inactive"  || "$(systemctl is-active nessusagent.service)" = "unknown" ]];
 then
      rpm -e NessusAgent
      gsutil cp gs://$bucketname/NessusAgent-8.3.1-es7.x86_64.rpm /home/packages
      echo "downloaded rpm package" > DownloadedRPMPackage
      rpm -ivh /home/packages/NessusAgent-8.3.1-es7.x86_64.rpm
      echo "**************Nessus agent is installed successfully ***************************"
      /opt/nessus_agent/sbin/nessuscli agent link --host=cloud.tenable.com --port=443 --key=$nessuskey --groups="'$NessusGroup'"
      echo "Linked successfully" > LinkedNessus
      sudo /bin/systemctl start nessusagent.service
      sudo /bin/systemctl status nessusagent.service
  fi
