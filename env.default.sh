#!/bin/env bash

# tmuxID is self-discovering and what allows the script to rename the tmux tab.
tmuxID=${tmuxID:-$(tmux display-message -p '#I')}

##
# If the below locations / options don't work for you, please create an env.sh with whatever variables you need to replace. ex:
#gitDir="$HOME/git/workspace/regressiontesting/wine-dirs/"
if [ -f "./env.sh" ]; then . ./env.sh; fi

# cores is how many cores your processor has that you want to use for compilation.
cores=${cores:-4}
# gitDir is the location where the workload generally happens.  It is NOT created by default and should be manually created.
gitDir=${gitDir:-"$HOME/git/workspace/regressiontesting/wine-dirs"}

# You probably only really want to change the above anyway, but for reference:
# buildPrefix is where the new wine gets built, wineDir and wineStaging are vanilla wine and wine-staging's git directories, respectively, that will be created.
buildPrefix=${buildPrefix:-"$gitDir/buildDir/"}
wineDir=${wineDir:-"$gitDir/wine-git/"}
wineStaging=${wineStaging:-"$gitDir/wine-staging/"}

##
# Input functions.
yesNo() {
  while true; do
    read -p "$*" -n 1 -r yn
    case $yn in
      [Yy]* ) return 0; break;;
      [Nn]* ) return 1; break;;
          * ) printf "\tPlease answer yes or no.\n";;
    esac
  done
}

##
# Check for sanity.
if [ ! -d "$gitDir" ]; then printf "$gitDir does not exist, exiting."; exit 1; fi
if [ ! -d "$buildPrefix" ]; then mkdir -p "$buildPrefix"; fi
if [ ! -d "$wineDir" ]; then
  if (yesNo "$wineDir does not exist, would you like to create and populate it?  "); then
    printf "\nCreating..."
    git clone https://github.com/wine-mirror/wine.git "$wineDir"
    if [ "$?" == 0 ]; then printf "\e[2K\rComplete!   \n"; else printf "\e[2K\rError detected -- exiting.\n"; exit 1; fi
  else
    printf "\nPlease create a custom env.sh with preferred directories.  Thank you!\n"
    exit 1
  fi
fi
if [ ! -d "$wineStaging" ]; then
  if (yesNo "$wineStaging does not exist, would you like to create and populate it?"  ); then
    print "\nCreating..."
    git clone https://github.com/wine-staging/wine-staging.git "$wineStaging"
    if [ "$?" == 0 ]; then printf "\e[2K\rComplete!   \n"; else printf "\e[2K\rError detected -- exiting.\n"; exit 1; fi
  else
    printf "\nPlease create a custom env.sh with preferred directories.  Thank you!\n"
    exit 1
  fi
fi

