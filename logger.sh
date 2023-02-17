#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
gold=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
gray=$(tput setaf 243)
default=$(tput sgr0)
bold=$(tput bold)

printError() {
	if [[ -z $2 ]]; then
  	echo -e "${red}${bold}ERROR:${default}${red} $1${default}" >> $cloudGamingLogFile
  else
  	echo -e "${red}${bold}ERROR:${default}${red} $1${default}"
  	echo -e "${red}${bold}ERROR:${default}${red} $1${default}" >> $cloudGamingLogFile
  fi
}

printWarn() {
	if [[ -z $2 ]]; then
  	echo -e "${gold}${bold}WARN:${default}${gold} $1${default}" >> $cloudGamingLogFile
  else
  	echo -e "${gold}${bold}WARN:${default}${gold} $1${default}"
  	echo -e "${gold}${bold}WARN:${default}${gold} $1${default}" >> $cloudGamingLogFile
  fi
}

printInfo() {
	if [[ -z $2 ]]; then
  	echo -e "${cyan}${bold}INFO:${default}${cyan} $1${default}" >> $cloudGamingLogFile
  else
  	echo -e "${cyan}${bold}INFO:${default}${cyan} $1${default}"
  	echo -e "${cyan}${bold}INFO:${default}${cyan} $1${default}" >> $cloudGamingLogFile
  fi
}