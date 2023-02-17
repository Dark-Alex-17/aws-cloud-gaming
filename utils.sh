#!/bin/bash
source logger.sh

TERMINAL_HEIGHT=$(tput lines)
BOX_HEIGHT=$(printf "%.0f" "$(echo "scale=2; $TERMINAL_HEIGHT * .5" | bc)")
GAUGE_BOX_HEIGHT=$(printf "%.0f" "$(echo "scale=2; $TERMINAL_HEIGHT * .25" | bc)")
TERMINAL_WIDTH=$(tput cols)
BOX_WIDTH=$(printf "%.0f" "$(echo "scale=2; $TERMINAL_WIDTH * .75" | bc)")
GAUGE_BOX_WIDTH=$(printf "%.0f" "$(echo "scale=2; $TERMINAL_WIDTH * .5" | bc)")

setConfigValue() {
	printInfo "Setting bashrc environment variable: $1=$2"

  if ( grep "$1" ~/.bashrc ); then
    sed -i "/$1=/c\export $1=$2" ~/.bashrc
  else
	  echo "export $1=$2" >> ~/.bashrc
	fi

	unset "$1"
	printf -v "$1" '%s' "$2"
}

msgBox() {
		whiptail --fb --msgbox "$1" "$BOX_HEIGHT" "$BOX_WIDTH"
}

showTailBox() {
	trap "kill $2 2> /dev/null" EXIT

	while kill -0 "$2" 2> /dev/null; do
		dialog --title "$1" --exit-label "Finished" --tailbox "$3" "$BOX_HEIGHT" "$BOX_WIDTH"
	done

	clear

	trap - EXIT
}

checkSudoPass() {
	printInfo "Prompting user for sudo password with message: $1"
	if [[ ! "$SUDO_PASSWORD" ]]; then
		SUDO_PASSWORD=$(whiptail --passwordbox "$1 Enter your sudo password" "$BOX_HEIGHT" "$BOX_WIDTH" 3>&2 2>&1 1>&3)
	fi
}

createMap() {
	declare prefix
	prefix=$(basename -- "$0")
  map=$(mktemp -dt "$prefix.XXXXXXXX")
  trap "rm -rf $map" EXIT
}

put() {
	declare mapName="$1"
	declare key="$2"
	declare value="$3"

	printInfo "Adding [$key: $value] to map $mapName"

	[[ -z $map ]] && createMap
	[[ -d "$map/$mapName" ]] || mkdir "$map/$mapName"

	echo "$value" >> "$map/$mapName/$key"
}

get() {
	declare mapName="$1"
	declare key="$2"

	[[ -z $map ]] && createMap
	cat "$map/$mapName/$key"

	printInfo "Fetched $map/$mapName/$key: $(cat $map/$mapName/$key)"
}