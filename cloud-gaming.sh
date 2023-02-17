#!/bin/bash
source ~/.bashrc
source aws-tools.sh
source logger.sh
source utils.sh
source stream-tools.sh

cloudGamingLogFile=/tmp/cloud-gaming.log
rm "$cloudGamingLogFile" > /dev/null 2>&1 &
export KERNEL=$(uname -s)

if [[ -z $AWS_CLOUD_GAMING_SSH_KEY ]]; then
	printError "The AWS_CLOUD_GAMING_SSH_KEY must be defined in order to use this script." true
	exit 1
fi

if [[ $KERNEL == "Darwin" ]]; then
	if ! (hash brew 2>/dev/null); then
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
fi

if ! (hash whiptail 2>/dev/null); then
  printWarn "whiptail is not installed. Installing now..." true

	if [[ $KERNEL == "Linux" ]]; then
		sudo apt-get -y install whiptail
	elif [[ $KERNEL == "Darwin" ]]; then
		yes | brew install whiptail
	fi
fi

createPrerequisitesMap() {
	declare mapName="prerequisites"
	declare linuxName="Linux"
	declare darwinName="Darwin"

	put $mapName "flatpak" $linuxName
	put $mapName "xvfb-run" $linuxName
	put $mapName "xdotool" $linuxName
	put $mapName "dialog" $linuxName
	put $mapName "pulsemixer" $linuxName
	put $mapName "nc" $linuxName
	
	put $mapName "mas" $darwinName
	put $mapName "python" $darwinName
	put $mapName "pulseaudio" $darwinName
	put $mapName "xdotool" $darwinName
	put $mapName "dialog" $darwinName
	put $mapName "pulsemixer" $darwinName
	put $mapName "nc" $darwinName
}

verifyPrerequisites() {
	printInfo "Verifying prerequisites"
	declare -a prerequisites

	createPrerequisitesMap
  prerequisites=($(ls $map/prerequisites/ | xargs -i basename {}))

  printInfo "Detected kernel: $KERNEL"

  for application in "${prerequisites[@]}"; do
  	declare value
  	value=$(get prerequisites "$application")

		if [[ ${value[*]} =~ $KERNEL ]] && ! (hash $application 2>/dev/null); then
			printWarn "$application is not installed. Installing now..." true

			if [[ $KERNEL == "Linux" ]]; then
				checkSudoPass "Installing $application requires sudo permissions."

				if [[ $application == "xvfb-run" ]]; then
					echo "$SUDO_PASSWORD" | sudo -k -S apt-get -y install xvfb
				elif [[ $application == "nc" ]]; then
					echo "$SUDO_PASSWORD" | sudo -k -S apt-get -y install netcat
				else
					echo "$SUDO_PASSWORD" | sudo -k -S apt-get -y install $application
				fi
			elif [[ $KERNEL == "Darwin" ]]; then
				if [[ $application == "pulsemixer" ]]; then
					pip install pulsemixer
				elif [[ $application == "nc" ]]; then
					yes | brew install netcat
				else
					yes | brew install $application
				fi
			fi
		fi
  done

	if [[ $KERNEL == "Linux" ]]; then
		if ! (flatpak info com.valvesoftware.SteamLink > /dev/null 2>&1); then
			printWarn "SteamLink is not installed. Installing now..." true
			checkSudoPass "Installing SteamLink requires sudo permissions."
			printWarn "Installing the FlatHub repo for Flatpak if it doesn't already exist..."
			echo "$SUDO_PASSWORD" | sudo -k -S flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
			printWarn "Installing SteamLink from FlatHub..."
			echo "$SUDO_PASSWORD" | sudo -k -S flatpak install flathub com.valvesoftware.SteamLink
		fi
#	elif [[ $KERNEL == "Darwin" ]]; then
		# TODO check if SteamLink is installed, and if not, install it via mas-cli
	fi

  if ! (hash aws 2> /dev/null); then
    printError "The AWS CLI must be installed to use this script. Please install the applicable AWS CLI from AWS and try again" true
    exit 1
  fi

  if ! (hash npm 2> /dev/null); then
    printError "NodeJS and NPM must be installed to use this script. Please install NodeJS and NPM and try again." true
    exit 1
  fi

  if [[ ! -f ~/.ssh/"$AWS_CLOUD_GAMING_SSH_KEY".pem ]]; then
  	printError "In order to use this script, you need to have the ~/.ssh/$AWS_CLOUD_GAMING_SSH_KEY key. Reach out to one of the team members to acquire it via Snappass and then try again." true
  	exit 1
	fi

  checkAwsProfile
}

verifyPrerequisites

checkInstanceStatus() {
  declare state
  state=$(getInstanceState)

  msgBox "Current instance state: $state"
  printInfo "Checking instance state. Received state: $state"
}

guideHostThroughSharedStreamSetup() {
	printInfo "Guiding user through host shared stream setup"

	msgBox "$(cat <<-EOF
		This will guide you through getting the other players connected to your personal EC2 instance.

		Hit 'OK' to start a desktop connection to your instance
	EOF
	)"

	msgBox "$(cat <<-EOF
		We now need to add your user's PINs to your steam client so they can connect to your instance.

		Hit 'OK' to start a desktop connection to your steam instance.
	EOF
	)"

  connectToInstanceViaDcvViewer

  printInfo "Directing user to enter PIN acquired from user's local SteamLinks"
	msgBox "$(cat <<-EOF
		On your EC2 Instance, in Steam, navigate to Steam -> Settings -> Remote Play.

		Click the 'Pair Steam Link' button and when prompted.
		Your users should have this connection PIN ready to give to you, so for each player, provide the PIN you received from them.

		Click 'OK' to exit the Steam settings menu when you've entered everyone's PINs and everyone confirms that they see your EC2 instance ready.

		Tell your users they can hit 'OK'.

		You're now ready to play!

		Hit 'OK' to finish the shared instance hosting setup and to start your stream!
	EOF
	)"

	stopStream
	startStream
}

guideClientThroughSharedStreamSetup() {
	printInfo "Guiding user through client shared stream setup"

	printInfo "Starting shared stream for client"
	printInfo "Starting SteamLink"
	flatpak run com.valvesoftware.SteamLink > /dev/null 2>&1 &

	printInfo "Prompting user to fetch the connection PIN from local SteamLink"
	msgBox "$(cat <<-EOF
		We need to get a unique PIN from SteamLink that will identify this machine for connection to the host's EC2 Instance.

		In SteamLink, do the following:

		1. Click on the gear icon in the top right hand corner.
		2. Then click on 'Computer'
		3. Click 'Other Computer'

		This will give you a PIN to enter into Steam on the host's EC2 instance.
		Give the host this PIN when prompted.

		Hit 'OK' when the host says to do so.
	EOF
	)"

	msgBox "$(cat <<-EOF
		You should see that EC2 instance highlighted as a streaming option with a big 'Start Playing' button. You're now ready to play!

		Finished setting up the shared stream. Have fun!
	EOF
	)"
}

startSharedStream() {
	if (whiptail --fb --title "Shared Stream Setup" --yesno "Are you hosting this shared stream?" --defaultno "$BOX_HEIGHT" "$BOX_WIDTH"); then
		printInfo "User is the HOST of the shared stream"

		guideHostThroughSharedStreamSetup
	else
		printInfo "User is a CLIENT of the shared stream"

		guideClientThroughSharedStreamSetup
	fi
}

streamSettings() {
  declare choice
  choice=$(whiptail --fb --title "Stream Settings" --menu "Select an option" "$BOX_HEIGHT" "$BOX_WIDTH" 4 \
    "P" "Start stream to (p)ersonal instance" \
    "S" "Start (S)hared stream" \
    "K" "(K)ill the stream" \
    "B" "(B)ack" 3>&2 2>&1 1>&3
  )

  case $choice in
    "P")
      startStream
      streamSettings
      ;;
    "S")
      startSharedStream
      streamSettings
      ;;
    "K")
    	stopStream
    	streamSettings
    	;;
    "B")
      mainMenu
      ;;
  esac
}

guideThroughSteamLink() {
	printInfo "Guiding user through SteamLink setup"

  msgBox "$(cat <<-EOF
		Now we need to set up SteamLink.

		First, we're going to connect to your instance via the fancy new NICE DCV viewer.
		Hit 'OK' when you're ready to log into your instance.
	EOF
	)"

	printInfo "Starting DCV Viewer connection to instance using cloud_gaming_dcv_profile.dcv profile"
	waitForInstanceToBecomeAvailable
  dcvviewer cloud_gaming_dcv_profile.dcv --certificate-validation-policy=accept-untrusted > /dev/null 2>&1 &

	printInfo "Directing user to log into Steam on the instance"
  msgBox "$(cat <<-EOF
		Next, we need to log into Steam. So start Steam and log into your account.

		For ease of use, check the 'Remember my password' box so you don't have to log in manually every time your instance starts.

		Hit 'OK' once you're logged in.
	EOF
	)"

  msgBox "$(cat <<-EOF
		Next, we need to connect your local SteamLink to this box.

		Hit 'OK' to start SteamLink
	EOF
	)"

	printInfo "Starting SteamLink"
  flatpak run com.valvesoftware.SteamLink > /dev/null 2>&1 &

	printInfo "Prompting user to fetch the connection PIN from local SteamLink"
  msgBox "$(cat <<-EOF
		Now, we need to get a unique PIN from SteamLink that will identify this machine for connection to your EC2 Instance.

		In SteamLink, do the following:

		1. Click on the gear icon in the top right hand corner.
		2. Then click on 'Computer'
		3. Click 'Other Computer'

		This will give you a PIN to enter into Steam on your EC2 instance. Hit 'OK' when you're ready to continue.
	EOF
	)"

	printInfo "Directing user to enter PIN acquired from local SteamLink"
  msgBox "$(cat <<-EOF
		On your EC2 Instance, in Steam, navigate to Steam -> Settings -> Remote Play.

		Click the 'Pair Steam Link' button and when prompted, provide the PIN you received from SteamLink in the last step.
		Click 'OK' to exit the Steam settings menu.

		Once you're done, your SteamLink should have the EC2 instance highlighted. Click on it and it should return you to the main menu.

		You should see that EC2 instance highlighted as a streaming option with a big 'Start Playing' button. You're now ready to play!

		Hit 'OK' to finish the one-time setup and return to the main menu.
	EOF
	)"

	printInfo "Killing dcvviewer, xvfb (if running, which it shouldn't be), and steamlink"
  pkill -9 -f dcvviewer > /dev/null 2>&1 &
  pkill -9 -f xvfb > /dev/null 2>&1 &
  pkill -9 -f steamlink > /dev/null 2>&1 &
}

deployInstance() {
  if (whiptail --fb --title "Deploy CDK" --yesno "This will now deploy the CDK for your cloud gaming instance. Do you wish to continue?" --defaultno "$BOX_HEIGHT" "$BOX_WIDTH"); then
    deployCdk
  fi

  if (whiptail --fb --title "Setup" --yesno "We'll now go through the first time setup. Do you wish to continue?" "$BOX_HEIGHT" "$BOX_WIDTH"); then
    msgBox "For first time setups, ensure your terminal is full screen so you don't miss any instructions. If it's not, exit this application, enter full screen, then start again"

    if (whiptail --fb --title "First Time Setup" --yesno "This will now perform first time setup for your cloud gaming instance. Is your terminal full screen?" --defaultno "$BOX_HEIGHT" "$BOX_WIDTH"); then
    	printInfo "Running first time setup"
      msgBox "For the first run, some manual, one-time setup steps are required. When ready, hit 'OK' to continue and start the connection to your instance's desktop."

      prepareStream
      guideThroughSteamLink

      msgBox "Finished setting up your instance. Have fun!"
    else
    	printInfo "User selected 'No' to running the first time setup. Nothing was done"
      msgBox "Nothing was done."
    fi
  fi
}

managePersonalInstance() {
  declare choice
  choice=$(whiptail --fb --title "Manage personal instance" --menu "Select an option" "$BOX_HEIGHT" "$BOX_WIDTH" 7 \
    "T" "Check instance s(t)atus" \
    "C" "(C)onnect to personal instance desktop via DCV Viewer" \
    "I" "D(i)sconnect from personal instance desktop" \
    "D" "(D)eploy a personal gaming instance" \
    "S" "(S)tart instance" \
    "K" "Stop instance" \
    "B" "(B)ack" 3>&2 2>&1 1>&3
  )

  case $choice in
    "T")
      checkInstanceStatus
      managePersonalInstance
      ;;
    "C")
    	connectToInstanceViaDcvViewer
    	managePersonalInstance
    	;;
		"I")
			printInfo "Killing connection to instance desktop via DCV Viewer"
			pkill -9 -f dcvviewer > /dev/null 2>&1 &
			managePersonalInstance
			;;
    "D")
      deployInstance
      managePersonalInstance
      ;;
    "S")
      startInstance
      managePersonalInstance
      ;;
    "K")
      stopInstance
      managePersonalInstance
      ;;
    "B")
      mainMenu
      ;;
  esac
}

mainMenu() {
  declare choice
  choice=$(whiptail --fb --title "Team Building Cloud Gaming" --menu "Select an option" "$BOX_HEIGHT" "$BOX_WIDTH" 3 \
    "M" "(M)anage your personal instance" \
    "S" "(S)tream settings" \
    "X" "E(x)it" 3>&2 2>&1 1>&3
  )

  case $choice in
    "M")
      managePersonalInstance
      ;;
    "S")
      streamSettings
      ;;
    "X")
      clear
      printInfo "Killing dcvviewer, xvfb, and steamlink"
      pkill -9 -f dcvviewer > /dev/null 2>&1 &
      pkill -9 -f xvfb > /dev/null 2>&1 &
      pkill -9 -f steamlink > /dev/null 2>&1 &
      if (whiptail --fb --title "Stop instance" --yesno "Do you wish to stop your instance before exiting?" "$BOX_HEIGHT" "$BOX_WIDTH"); then
			  stopInstance
			fi
      printInfo "Exiting"
      exit 0
      ;;
  esac
}

while :; do
  mainMenu
done