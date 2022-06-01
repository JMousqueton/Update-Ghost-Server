#!/bin/bash 
#Ghost Self-Hosted Update

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow
On_Blue='\033[44m'        # Blue
On_Purple='\033[45m'      # Purple
On_Cyan='\033[46m'        # Cyan
On_White='\033[47m'       # White

# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White

# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\033[0;100m'   # Black
On_IRed='\033[0;101m'     # Red
On_IGreen='\033[0;102m'   # Green
On_IYellow='\033[0;103m'  # Yellow
On_IBlue='\033[0;104m'    # Blue
On_IPurple='\033[0;105m'  # Purple
On_ICyan='\033[0;106m'    # Cyan
On_IWhite='\033[0;107m'   # White


mlocate_check ()
{
  echo "Checking for curl..."
  if command -v mlocate > /dev/null; then
    echo "Detected mlocate..."
  else
    echo "Installing mlocate..."
    sudo apt-get install -q -y mlocate
    if [ "$?" -ne "0" ]; then
      echo "Unable to install mlocate ! Your base system has a problem; please check your default OS's package repositories because mlocate should work."
      echo "Repository installation aborted."
      exit 1
    fi
  fi
}

# SET BLOG INSTALL PATH
#--------------------------------------------------------
mlocate_check
echo "Update mlocate database" 
sudo updatedb
echo -n "Get Ghost home directory ... "
ghost_home="$(sudo locate -b '\.ghost-cli' | xargs -n 1 dirname)" 
echo -e "${Green}$ghost_home${Color_Off}"

# GET INSTALLED AND LATEST VERSION 
#--------------------------------------------------------
echo -n "Get Ghost installed Version ... " 
ghost_installed="$(grep active-version $ghost_home/.ghost-cli | cut -d\" -f 4)"
echo -e "${Green}$ghost_installed${Color_Off}" 
echo -n "Get Latest Ghost Version ... "
ghost_latest="$(basename $(curl -fs -o/dev/null -w %{redirect_url} https://github.com/tryghost/ghost/releases/latest)| cut -c 2-)"
echo -e "${Green}$ghost_latest${Color_Off}"


# GET GHOST URL 
#--------------------------------------------------------
echo -n "Get Ghost URL ... "
ghost_url="$(grep url $ghost_home/config.production.json | cut -d\" -f 4)"
echo -e "${Green}$ghost_url${Color_Off}"

upgrade_required="no"
set -f
array_ghost_installed=(${ghost_installed//./ })
array_ghost_latest=(${ghost_latest//./ })
 
if (( ${#array_ghost_installed[@]} == "2" ))
then
    array_ghost_installed+=("0")
fi
 
for ((i=0; i<${#array_ghost_installed[@]}; i++))
do
    if (( ${array_ghost_installed[$i]} < ${array_ghost_latest[$i]} ))
    then
    upgrade_required="yes"
    fi
done

# GET UPDATE OS 
#--------------------------------------------------------
echo "Update OS"
sudo apt -y dist-upgrade --auto-remove --purge


# GHOST UPGRADE SECTION
#--------------------------------------------------------
case $upgrade_required in
    no)
    printf "\nGhost v${Green}%s${Color_Off} is installed with the lastest version. No upgrade required.\n" "$ghost_installed"
    ;;
    yes)
    printf "\nUpdating Ghost from v${Red}%s${Color_Off} to v${Green}%s${Color_Off}.\n\n" "$ghost_installed" "$ghost_latest"

    cd $ghost_home

    printf 'Update Access Permissions\n\n'
    sudo chown -R ghost:ghost ./content
    sudo find ./ ! -path "./versions/*" -type f -exec chmod 664 {} \; 

    printf 'Update Ghost'
    ghost update 

    echo 'Checking the blog in 10 seconds'
    sleep 10 
    status_code=$(curl --write-out %{http_code} --silent --output /dev/null $ghost_url) 

    if [[ "$status_code" -ne 200 ]] ; then
        echo -e "Error : Site status ${Red}$status_code${Color_Off}" 
    else
        echo 'The Blog is responding' 
    fi    
    ;;
esac

# REBOOT IF NEEDED 
if [ -f /var/run/reboot-required ]; then
  echo 'reboot required ... waiting 10 seconds'
  sleep 10
  sudo reboot
fi
