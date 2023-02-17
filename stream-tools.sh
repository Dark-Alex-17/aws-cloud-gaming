#!/bin/bash
source aws-tools.sh
source logger.sh
source utils.sh

prepareStream() {
	printInfo "Preparing stream and configuring NICE DCV Viewer"

  checkSudoPass "Installing NICE DCV Client requires sudo permissions."

  declare architecture
  architecture=$(uname -p)

  printInfo "Detected architecture: $architecture"

  {
    echo -e "XXX\n0\nInstalling NICE DCV Client... \nXXX"
    printInfo "Installing NICE DCV Viewer client"
#    if [[ $kernel == "Linux" ]]; then
    	wget -o nice-dcv-viewer.deb https://d1uj6qtbmh3dt5.cloudfront.net/2022.1/Clients/nice-dcv-viewer_2022.1.4251-1_amd64.ubuntu2004.deb > /dev/null 2>&1
    	echo "$SUDO_PASSWORD" | sudo -k -S sh -c "dpkg -i nice-dcv-viewer.deb" > /dev/null 2>&1
#    elif [[ $kernel == "Darwin" ]]; then
#    	if [[ $architecture == "x86_64" ]]; then
#				wget -o nice-dcv-viewer.dmg https://d1uj6qtbmh3dt5.cloudfront.net/2022.1/Clients/nice-dcv-viewer-2022.1.4279.x86_64.dmg > /dev/null 2>&1
#    	elif [[ $architecture == "arm64" ]]; then
#				wget -o nice-dcv-viewer.dmg https://d1uj6qtbmh3dt5.cloudfront.net/2022.1/Clients/nice-dcv-viewer-2022.1.4279.arm64.dmg > /dev/null 2>&1
#    	fi
#
#			TODO figure out how to install dcvviewer and how to run it on a Mac
#    	echo "$SUDO_PASSWORD" | sudo -k -S sh -c "sudo hdiutil attach nice-dcv-viewer.dmg"
#		fi
    echo -e "XXX\n33\nCleaning up... \nXXX"
    printInfo "Removing downloaded DCV Viewer installation"
    rm nice-dcv-viewer* > /dev/null 2>&1
    echo -e "XXX\n66\nCreating Connection Profile from template... \nXXX"
    createDcvConnectionProfileFromTemplate
    echo -e "XXX\n100\nDone! \nXXX"
    sleep 1
  } | whiptail --title "Installing NICE DCV Client..." --gauge "Installing NICE DCV Client..." "$GAUGE_BOX_HEIGHT" "$GAUGE_BOX_WIDTH" 0
}

startStream() {
	printInfo "Starting stream"
  if ! (hash dcvviewer 2> /dev/null); then
  	printError "Unable to start stream: dcvviewer is not installed"
    msgBox "Can't stream without first time setup. Run the deploy instance task from the instance management menu first!"
    return 0
  fi

  if (pgrep -f dcvviewer || pgrep -f steam); then
  	printError "Stream is already running."
    msgBox "Stream is already running"
    return 0
  fi

  declare state
  state=$(getInstanceState)
  if [[ $state != "running" ]]; then
    if (whiptail --fb --title "Start your instance?" --yesno "In order to stream, you instance needs to be started. Would you like to start your personal instance?" "$BOX_BOX_HEIGHT" "$BOX_WIDTH"); then
      startInstance
    else
    	printError "Unable to start stream: Instance is not running"
      msgBox "Can't stream! Instance is not running. You can start the instance from the Instance Management menu."
      return 0
    fi
  fi

	printInfo "Starting dcvviewer in background"
  xvfb-run -a dcvviewer cloud_gaming_dcv_profile.dcv --certificate-validation-policy=accept-untrusted > /dev/null 2>&1 &
  sleep 0.25

  printInfo "Minimizing active window"
  xdotool windowminimize $(xdotool getactivewindow)
  printInfo "Muting DCV Viewer"
  pulsemixer --toggle-mute --id $(pulsemixer -l | grep dcvviewer | awk '{ print $4; }' | sed 's/,//g') > /dev/null 2>&1
  sleep 0.25

	printInfo "Starting SteamLink"
  flatpak run com.valvesoftware.SteamLink > /dev/null 2>&1 &
}

stopStream() {
	printInfo "Stopping the stream"
  pkill -9 -f dcvviewer > /dev/null 2>&1 &
  pkill -9 -f xvfb > /dev/null 2>&1 &
  pkill -9 -f steamlink > /dev/null 2>&1 &

	printInfo "Stopped the stream"
  msgBox "Successfully killed the stream"
}