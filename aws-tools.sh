#!/bin/bash
source ~/.bashrc
source logger.sh
source utils.sh

if [[ -z $AWS_CLOUD_GAMING_PROFILE ]]; then
	AWS_CLOUD_GAMING_PROFILE=personal
fi

checkAwsProfile() {
	printInfo "Checking for the $AWS_CLOUD_GAMING_PROFILE AWS Profile in AWS config"
  if ! (aws --profile $AWS_CLOUD_GAMING_PROFILE sts get-caller-identity --no-cli-auto-prompt > /dev/null 2>&1); then
  	printError "AWS config is missing the $AWS_CLOUD_GAMING_PROFILE profile. Add it to your ~/.aws/config file and try running this application again"
  	exit 1
  fi
}

getInstanceState() {
  aws --profile $AWS_CLOUD_GAMING_PROFILE ec2 describe-instances --instance-ids "$AWS_TEAM_BUILDING_EC2_INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --no-cli-auto-prompt --output text &
}

showGaugeBoxForAwsCommand() {
  declare increment
  declare i
  increment=$(echo "scale=1; 100 / 30" | bc)
  i="0"

  printInfo "$2"

  {
    while [[ $(getInstanceState) != "$1" ]]; do
      declare percent
      percent=$(printf "%.0f" $i)
      echo -e "XXX\n$percent\n$2... \nXXX"
      i=$(echo "$i + $increment" | bc)
      sleep 5
    done

    if [[ $(getInstanceState) != "$1" ]]; then
    	printError "$4"
      echo -e "XXX\n0\n$4\nXXX"
      return 1
    else
      echo -e "XXX\n100\n$3\nXXX"
      sleep 1
    fi
  } | whiptail --title "$2..." --gauge "$2..." "$GAUGE_BOX_HEIGHT" "$GAUGE_BOX_WIDTH" 0

  printInfo "$3"
}

waitForInstanceToBecomeAvailable() {
	printInfo "Waiting for instance to become available"

	{
		declare increment
		increment=$(echo "scale=1; 100/90" | bc)
		for ((i=0; i<=100; i=$(printf "%.0f" $(echo "scale=1; $i + $increment" | bc)))); do
			if (timeout 10s nc -vz "$AWS_TEAM_BUILDING_EC2_INSTANCE_IP" 8443); then
				break
			fi
			echo "$i"
		done
		echo 100
		sleep 1
	} | whiptail --title "Instance Startup" --gauge "Waiting for instance to become available..." "$GAUGE_BOX_HEIGHT" "$GAUGE_BOX_WIDTH" 0
}

getInstanceIp() {
	printInfo "Fetching instance IP for id: $AWS_TEAM_BUILDING_EC2_INSTANCE_ID"
	aws --profile $AWS_CLOUD_GAMING_PROFILE ec2 describe-instances --instance-ids "$AWS_TEAM_BUILDING_EC2_INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --no-cli-auto-prompt
}

createDcvConnectionProfileFromTemplate() {
	printInfo "Creating DCV connection profile from template"
	PASSWORD="$(aws --profile $AWS_CLOUD_GAMING_PROFILE ec2 get-password-data --instance-id "$AWS_TEAM_BUILDING_EC2_INSTANCE_ID" --priv-launch-key ~/.ssh/"$AWS_CLOUD_GAMING_SSH_KEY".pem --query 'PasswordData' --output text --no-cli-auto-prompt)"
  PASSWORD=$(echo -n $PASSWORD)
	sed -i "/^host=/c\host=$AWS_TEAM_BUILDING_EC2_INSTANCE_IP" cloud_gaming_dcv_profile.dcv
	sed -i "/^password=/c\password=$PASSWORD" cloud_gaming_dcv_profile.dcv
}

startInstance() {
  declare state
  declare desiredState=running
  state=$(getInstanceState)
  printInfo "Starting instance"

  if [[ $state == "$desiredState" ]]; then
  	printError "Instance is already running. Doing nothing"
    msgBox "Instance is already running."
  else
  	declare instanceIp
    aws --profile $AWS_CLOUD_GAMING_PROFILE ec2 start-instances --instance-ids "$AWS_TEAM_BUILDING_EC2_INSTANCE_ID" --no-cli-auto-prompt > /dev/null 2>&1 &
    showGaugeBoxForAwsCommand "$desiredState" "Starting Your Instance" "Successfully Started Your Instance!" "Failed to start your instance!"
    printInfo "Checking to see if IP changed"
  	instanceIp=$(getInstanceIp)
  	if [[ $instanceIp != "$AWS_TEAM_BUILDING_EC2_INSTANCE_IP" ]]; then
  		setConfigValue "AWS_TEAM_BUILDING_EC2_INSTANCE_IP" "$instanceIp"
  		export AWS_TEAM_BUILDING_EC2_INSTANCE_IP="$instanceIp"
  		createDcvConnectionProfileFromTemplate
  	fi

    waitForInstanceToBecomeAvailable

  fi
}

stopInstance() {
  declare state
  declare desiredState=stopped
  state=$(getInstanceState)
  printInfo "Stopping instance"

  if [[ $state == "$desiredState" ]]; then
  	printError "Instance is already stopped."
    msgBox "Instance is already stopped."
  else
    aws --profile $AWS_CLOUD_GAMING_PROFILE ec2 stop-instances --instance-ids "$AWS_TEAM_BUILDING_EC2_INSTANCE_ID" --no-cli-auto-prompt > /dev/null 2>&1 &
    showGaugeBoxForAwsCommand "$desiredState" "Stopping Your Instance" "Successfully Stopped Your Instance!" "Failed to stop your instance!"
  fi
}

rebootInstance() {
  declare desiredState=running

  printInfo "Rebooting instance"

  aws --profile $AWS_CLOUD_GAMING_PROFILE ec2 reboot-instances --instance-ids "$AWS_TEAM_BUILDING_EC2_INSTANCE_ID" --no-cli-auto-prompt > /dev/null 2>&1 &

  if ! (showGaugeBoxForAwsCommand "$desiredState" "Restarting Your Instance" "Successfully Restarted Your Instance!"); then
  	printError "Failed to restart instance. Waiting for user to manually start instance before continuing."
    msgBox "$(cat <<-EOF
			Failed to restart your instance! Please make sure your instance is started before continuing!

			Your instance ID is $AWS_TEAM_BUILDING_EC2_INSTANCE_ID

			Hit 'OK' Once your instance is started
		EOF
		)"
  fi
}

getMyIp() {
	curl -s -L -X GET http://checkip.amazonaws.com
}

deployCdk() {
	printInfo "Deploying CDK"

  cd cdk

  declare user
  declare localIp
  declare logFile=/tmp/cdk
  user="$(whoami)"
	localIp="$(getMyIp)"

  {
    echo -e "XXX\n0\nRunning npm install... \nXXX"
    printInfo "Running npm install"
    npm install > /dev/null 2>&1
    echo -e "XXX\n50\nBuilding CDK... \nXXX"
    printInfo "Running npm run build"
    npm run build > /dev/null 2>&1
    echo -e "XXX\n100\nDone! \nXXX"
    sleep 1
  } | whiptail --title "Preparing CDK..." --gauge "Preparing CDK..." "$GAUGE_BOX_HEIGHT" "$GAUGE_BOX_WIDTH" 0

  declare pid
  declare bootstrapLogFile="${logFile}-bootstrap.log"
  printInfo "Bootstrapping CDK and logging to $bootstrapLogFile"
  yes | npx cdk --no-color --require-approval never --profile $AWS_CLOUD_GAMING_PROFILE -c "user=$user" -c "localIp=$localIp" bootstrap > $bootstrapLogFile 2>&1 &
  pid=$!
  showTailBox "Bootstrapping CDK" $pid $bootstrapLogFile

  declare deployLogFile="${logFile}-deploy.log"
  printInfo "Deploying CDK and logging to $deployLogFile"
  yes | npx cdk --no-color --require-approval never --profile $AWS_CLOUD_GAMING_PROFILE -c "user=$user" -c "localIp=$localIp" deploy "TeamBuildingCloudGaming-$user" > $deployLogFile 2>&1 &
  pid=$!
  showTailBox "Deploy EC2 Instance" $pid $deployLogFile

  unset AWS_TEAM_BUILDING_EC2_INSTANCE_ID
  unset AWS_TEAM_BUILDING_EC2_INSTANCE_IP

  AWS_TEAM_BUILDING_EC2_INSTANCE_ID=$(cat $deployLogFile | grep InstanceId | awk '{print $NF;}')
  setConfigValue "AWS_TEAM_BUILDING_EC2_INSTANCE_ID" "$AWS_TEAM_BUILDING_EC2_INSTANCE_ID"

  AWS_TEAM_BUILDING_EC2_INSTANCE_IP=$(getInstanceIp)
  setConfigValue "AWS_TEAM_BUILDING_EC2_INSTANCE_IP" "$AWS_TEAM_BUILDING_EC2_INSTANCE_IP"

  cd ..

  waitForInstanceToBecomeAvailable
	rebootInstance
	waitForInstanceToBecomeAvailable
}

connectToInstanceViaDcvViewer() {
	printInfo "Connecting to instance desktop via DCV Viewer"

	if ! (hash dcvviewer 2> /dev/null); then
		printError "dcvviewer is not installed. Cannot connect to personal instance until first time setup is run."
		msgBox "Can't connect to personal instance via DCV Viewer without first time setup. Run the deploy instance task from the instance management menu first!"
	fi

	if (pgrep -f dcvviewer); then
		printError "DCV Viewer is already running."
		msgBox "DCV Viewer is already running"
		return 0
	fi

	declare state
	state=$(getInstanceState)
	if [[ $state != "running" ]]; then
		if (whiptail --fb --title "Start your instance?" --yesno "In order to stream, you instance needs to be started. Would you like to start your personal instance?" "$BOX_BOX_HEIGHT" "$BOX_WIDTH"); then
			startInstance
		else
			printError "Unable to start desktop connection: Instance is not running"
			msgBox "Can't start desktop connection! Instance is not running. You can start the instance from the personal Instance Management menu."
			return 0
		fi
	fi

	dcvviewer cloud_gaming_dcv_profile.dcv --certificate-validation-policy=accept-untrusted > /dev/null 2>&1 &
}