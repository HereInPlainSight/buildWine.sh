#!/bin/env bash

##
# Usage:
# ./script.sh <bisect>  [stagingPatches]
# ./script.sh <vanilla> [tag] [stagingPatches]
# ./script.sh <staging> [tag]

##
# Pull in the default environment.
. ./env.default.sh

##
# This is INCREDIBLY BAD PRACTICE.
# FIX this mess when I'm not sick.  Or at least when I'm more awake and less medicated.
hashId=""
timestamp=""
config64=""
timer64bc=""
make64=""
timer64bm=""
install64=""
timer64bi=""
config32=""
timer32bc=""
make32=""
timer32bm=""
install32=""
timer32bi=""

##
# Function for timing things, thank you internet.
# https://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
seconds2time (){
   T=$1
   D=$((T/60/60/24))
   H=$((T/60/60%24))
   M=$((T/60%60))
   S=$((T%60))

   if [[ ${D} != 0 ]]
     then
   printf '%d days %02d:%02d:%02d' $D $H $M $S
     else
   printf '%02d:%02d:%02d' $H $M $S
   fi
}

housekeeping(){
  ##
  # First wipe out the existing buildPrefix.
  rm -rf "$buildPrefix"/*

  tmux rename-window -t $tmuxID "(0/6) housekeeping"
  buildStartTime=$(date +%s)

  ##
  # Let's get started.
  pushd "$wineDir"
  ##
  # If we're not bisecting, clear out changes in wine-git and update.  Switch to tag.
  if [ "$prefix" != "bisect" ]; then
    ##
    # Clear out changes in wine-git.  Also update.
    git am --abort
    git reset --hard origin/master
    git checkout master
    git pull
    if [ ! -z "$tag" ]; then
      git checkout "wine-$tag"
    fi
  fi

  hashId=$(echo $(git log --pretty=format:'%h' -n 1))
  timestamp=$(echo $(git show -s --format=%ci))

  ##
  # Patch if we're below 6.8.
  gitThinksWeAt=$(git describe --tag --abbrev=0 | sed 's/^.\{5\}//')
  if (( $(echo "$gitThinksWeAt <= 6.8" | bc -l) )); then
    patch -p1 < ../patches/sincos.patch
  fi
  popd
}

bisectPatch(){
  ##
  # Go to wine-staging and apply the requested patches.
  pushd "$wineStaging" 				# Match timestamp in staging...
  git checkout `git rev-list -1 --before="$timestamp" master`
  pushd "$wineDir"				# Apply patch from staging to wine-git.
  "$wineStaging"/staging/patchinstall.py -d "$wineDir" "$stagingPatches"
  popd
  if [ "$?" -ne 0 ]; then			# But if it doesn't sync against the before-timestamp try the timestamp after.
    git checkout `git rev-list -1 --after="$timestamp" master`
    pushd "$wineDir"
    "$wineStaging"/staging/patchinstall.py -d "$wineDir" "$stagingPatches"
    popd
    if [ "$?" -ne 0 ]; then			# Aaaand if it doesn't sync from either of them, #feelsbadman.
      printf "\nError: Patching failed!\n"
      exit 1;
    fi
  fi
  popd
}

vanillaPatch(){
  ##
  # Go to wine-staging and apply the requested patches.
  pushd "$wineStaging"
  git reset --hard origin/master
  git checkout master
  git pull
  if [ ! -z "$tag" ]; then
    git checkout "v$tag"
  fi
  popd

  # Apply requested staging patches.
  pushd "$wineDir"
  "$wineStaging"/staging/patchinstall.py -d "$wineDir" "$stagingPatches"
  if [[ $? -ne 0 ]]; then
    printf "\nError: Staging patches failed to apply!\n"
    exit 1
  fi
  popd
}

stagingPatch(){
  ##
  # Update staging and sync to requested tag.
  pushd "$wineStaging"
  git reset --hard origin/master
  git checkout
  git pull
  if [ ! -z "$tag" ]; then
    git checkout "v$tag"
  fi
  popd

  # Apply full staging patches.
  pushd "$wineDir"
  "$wineStaging"/staging/patchinstall.py -a --backend=git-am --force-autoconf -d "$wineDir"
  popd
}

##
# ...  Yes.
buildWine(){
  pushd "$gitDir"
  ##
  # 64-bit
  pushd wine64-build
  tmux rename-window -t $tmuxID "(1/6) wine64-build-conf"
  printf "==================== (1/6) wine64-build-conf ====================\n"
  startTime=$(date +%s)
  CC="ccache gcc" "$wineDir"/configure --prefix="$buildPrefix/opt" --verbose --disable-tests --enable-win64
  config64="$?"
  if [ $config64 != 0 ]; then exit; fi
  timer64bc=$(seconds2time $(echo "$(date +%s) - $startTime" | bc))
  tmux rename-window -t $tmuxID "(2/6) wine64-build-make"
  printf "==================== (2/6) wine64-build-make ====================\n"
  startTime=$(date +%s)
  make -j$cores
  make64="$?"
  if [ $make64 != 0 ]; then exit; fi
  timer64bm=$(seconds2time $(echo "$(date +%s) - $startTime" | bc))
  tmux rename-window -t $tmuxID "(3/6) wine64-build-install"
  printf "==================== (3/6) wine64-build-install ====================\n"
  startTime=$(date +%s)
  make install
  install64="$?"
  if [ $install64 != 0 ]; then exit; fi
  timer64bi=$(seconds2time $(echo "$(date +%s) - $startTime" | bc))
  popd

  ##
  # 32-bit
  pushd wine32-build
  tmux rename-window -t $tmuxID "(4/6) wine32-build-conf"
  printf "==================== (4/6) wine32-build-conf ====================\n"
  startTime=$(date +%s)
  CC="ccache gcc -m32" PKG_CONFIG_PATH=/usr/lib/pkgconfig "$wineDir"/configure --prefix="$buildPrefix/opt" --with-wine64="$gitDir"/wine64-build --verbose --disable-tests
  config32="$?"
  timer32bc=$(seconds2time $(echo "$(date +%s) - $startTime" | bc))
  tmux rename-window -t $tmuxID "(5/6) wine32-build-make"
  printf "==================== (5/6) wine64-build-make ====================\n"
  startTime=$(date +%s)
  make -j$cores
  make32="$?"
  timer32bm=$(seconds2time $(echo "$(date +%s) - $startTime" | bc))
  tmux rename-window -t $tmuxID "(6/6) wine32-build-install"
  printf "==================== (6/6) wine64-build-install ====================\n"
  startTime=$(date +%s)
  make install
  install32="$?"
  timer32bi=$(seconds2time $(echo "$(date +%s) - $startTime" | bc))
  popd

  ##
  # Stash the changes from applying the staging patch(es) / compilation patch.  Also, chuck 'em.
  pushd "$wineDir/"
  git stash
  git stash drop
  popd
  popd
}

##
# End of abstractions.
prefix="$1"
tag=""
stagingPatches=""
case "$prefix" in
  b|-b|bisect)
     prefix="bisect"
     housekeeping
     if [ "${@:2}" != "" ]; then
       stagingPatches="${@:2}"
       bisectPatch
     fi
     buildWine
     ;;
  v|-v|vanilla)
     prefix="vanilla"
     if [ "$2" != "" ]; then tag="$2"; fi
     housekeeping
     if [ "${@:3}" != "" ]; then
       stagingPatches="${@:3}"
       vanillaPatch
     fi
     buildWine
     ;;
  s|-s|staging)
     prefix="staging"
     if [ "$2" != "" ];	then tag="$2"; fi
     housekeeping
     stagingPatch
     buildWine
     ;;
  -h|--help)
     printf "Usage:
     $0 <bisect> [stagingPatches]
     $0 <vanilla> [tag] [stagingPatches]
     $0 <staging> [tag]\n"
     exit 0;;
  *) echo "Unrecognized request, exiting."
     exit 1;;
esac

##
# Done.  Reset window name and show timers, tar up the bisect and output filename.
tmux rename-window -t $tmuxID "Finalizing..."
tarName=$(printf "%b" "$prefix$([ ! -z "$tag" ] && printf "%b" "-$tag")$([ ! -z "$hashId" ] && printf "%b" "-$hashId")")
printf "\nPreparing archive: wine-$tarName.tar.gz\n"
printf "
############### $(seconds2time $(echo "$(date +%s) - $buildStartTime" | bc)) ###############
%-3s %-11s %-5s %18s
%-3s %-11s %-5s %18s
%-3s %-11s %-5s %18s
%-3s %-11s %-5s %18s
%-3s %-11s %-5s %18s
%-3s %-11s %-5s %18s
" "64:" "config:" $config64 $timer64bc "64:" "make:" $make64 $timer64bm "64:" "install:" $install64 $timer64bi "32:" "config:" $config32 $timer32bc "32:" "make:" $make32 $timer32bm "32:" "install:" $install32 $timer32bi
startTime=$(date +%s)
printf "Creating archive..."
mv "$buildPrefix/opt" "$buildPrefix/wine-$tarName"
tar -caf "wine-$tarName.tar.gz" -C "$buildPrefix" .
taredUp="$?"
tarTime=$(seconds2time $(echo "$(date +%s) - $startTime" | bc))
printf "\33[2K\rArchive:        %-5s %18s\a\n" $taredUp $tarTime
tmux rename-window -t $tmuxID "Rebuild Window"
printf "%s %s %s\n" "$0" "$@" "$tarName"

