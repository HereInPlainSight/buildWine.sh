# buildWine.sh
## _A script to compile wine in a very lazy way_

(This script works, but I never got around to cleaning it up.  Still, it does the job, if the job is lazily doing a bisect.)

This is a script designed to compile wine, primarily with the intention of being used hand-in-hand with bisecting wine to find regressions.  It used to be three different scripts, but I got sick and hapazardly put them all together into one.

This is NOT recommended for making builds to run games on, this is to find *problems*.  There's nothing special in these builds, they are *basic* so that you can report the regression with as *little* interference from outside the regression as possible to wine's [bug tracker](https://bugs.winehq.org/).

## Requirements:
- A bash environment with read / write permissions for the user running the scripts.
- git, grep, and tar
- The build and runtime dependencies required to compile wine, recommended reading is [here](https://wiki.winehq.org/Building_Wine).
- tmux, while not required, is recommended.

## Features
- That's a little optimistic for what this is, don't you think?

## Installation
Uhh, okay.  Clone the repo and make the `$gitDir` so things don't explode, I guess.  You can make an executable env.sh to override the default directories and options.  Defaults are shown here:

```sh
cores=4                                                             # Number of cores to use when compiling.
gitDir="$HOME/git/workspace/regressiontesting/wine-dirs/"           # Manually-created location where we store all our working directories.

# Unlikely you'll need to change these, as they're all created and populated when the script's run, but:
buildPrefix="$gitDir/buildDir/"                                     # Location the new wine gets built in.
wineDir="$gitDir/wine-git/"                                         # Vanilla wine's git repo directory.
wineStaging="$gitDir/wine-staging/"                                 # Wine-staging's git repo directory.
```

## Usage (or, how to run a basic regression.)
Ideally you'd have a tmux session open so you'll know where you are in the compilation process.  Generally, I'll keep two windows open in tmux -- one in the directory with these scripts, the other, in `$wineDir`.  Since this is generally used for regressions, the first thing you should do is find out where the regression first begins at.  Use precompiled builds (such as from Lutris or what have you) or build it on your own.  Confirm if the issue is in staging or not.
```sh
./buildWine.sh vanilla <tag> <staging patches>              # <tag> in the format of, for example, "7.13"
                                                            # <staging patches> in the format of "ntdll-Hide_Wine_Exports", space separated in the case of multiple required staging patches.  Should ONLY be used if staging patches are REQUIRED to run the application in question!
./buildWine.sh staging <tag>                                # If <tag> is not specified, latest available git version is compiled!  Yes, currently there is no way to specify staging patch(es) without specifying a tag!
```
Keep testing the builds.  Found the first tag a regression happens at?  *Confirmed* it's between two specific tags, ie, 7.1 and 7.2?  Sweet.  Some work to do in the `$wineDir`.
```sh
git bisect start
git bisect bad wine-<bad tag #>                             # <bad tag #> in the example would be 7.2, when the bug showed up.
git bisect good wine-<good tag #>                           # <good tag #> in the example would be 7.1, when the bug wasn't present.
```
Great.  Switch back to the scripts window in tmux, and compile.
```sh
./buildWine.sh bisect <staging patches>                     # Again, the ONLY patches that should be applied to staging are REQUIRED staging patches to run the game in question ONLY!  If it runs BADLY, that's a different problem!  ONE problem at a time!
```
Did it work?  Great, back in the `$wineDir` window, tell git.  If it didn't -- tell it that, instead.
```sh
git bisect good|bad
```
KEEP DOING this.  Alternate your `./buildWine.sh bisect` command and your `git bisect` command.  When you're done, you'll get told what the bad commit is -- confirm you can't find a duplicate for your problem on wine's bugzilla.  If you do, post a confirmation!  If there wasn't a specific commit mentioned as a regression, mention it!  If there's no existing report, submit one, with a description of the bug and the regression information!
