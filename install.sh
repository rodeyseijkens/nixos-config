#!/usr/bin/env bash

#--------------------#
#   Initialisation   #
#--------------------#

CURRENT_USERNAME='rodey'

RESET=$(tput sgr0)
WHITE=$(tput setaf 7)
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BRIGHT=$(tput bold)
UNDERLINE=$(tput smul)

OK="[${GREEN}OK${RESET}]\t"
INFO="[${BLUE}INFO${RESET}]\t"
WARN="[${MAGENTA}WARN${RESET}]\t"
ERROR="[${RED}ERROR${RESET}]\t"

set -e

#------------------------------#
#   Check if running as root   #
#------------------------------#

if [[ $EUID -eq 0 ]]; then
    echo -e "${ERROR}This script should ${RED}NOT${RESET} be executed as root!"
    echo -e "${INFO}Exiting..."
    exit 1
fi

#---------------------#
#   Greeting Banner   #
#---------------------#

clear

echo -E "$CYAN
     _   _ _       ___        ___           _        _ _           
    | \ | (_)_  __/ _ \ ___  |_ _|_ __  ___| |_ __ _| | | ___ _ __ 
    |  \| | \ \/ / | | / __|  | || '_ \/ __| __/ _' | | |/ _ \ '__|
    | |\  | |>  <| |_| \__ \  | || | | \__ \ || (_| | | |  __/ |   
    |_| \_|_/_/\_\\\\___/|___/ |___|_| |_|___/\__\__,_|_|_|\___|_| 


       ${BLUE} ─── https://github.com/rodeyseijkens/nixos-config ─── ${RESET}
"

#------------------#
#   Get username   #
#------------------#

while true; do
    echo -en "${INFO}Enter your ${GREEN}username${RESET}: ${YELLOW}"
    read username
    echo -en "${RESET}"

    if [ -z "$username" ]; then
        echo -e "${ERROR}Username cannot be empty!"
        continue
    fi

    if ! [[ $username =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        echo -e "${ERROR}Invalid username: '$username'"
        echo -e "${INFO}Username must start with a lowercase letter and contain only lowercase letters, digits, hyphens, and underscores (max 32 chars)"
        continue
    fi

    echo -en "${INFO}Use ${YELLOW}'$username'${RESET} as username? [${GREEN}y${RESET}/${RED}n${RESET}]: "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        break
    fi
done

#-----------------#
#   Choose host   #
#-----------------#

while true; do
    echo -en "${INFO}Choose a ${GREEN}host${RESET} - [${YELLOW}D${RESET}]esktop, Desktop-[${YELLOW}W${RESET}]ork, Desktop-[${YELLOW}O${RESET}]ffice: "
    read -n 1 -r
    echo

    if [[ $REPLY =~ ^[Dd]$ ]]; then
        HOST='desktop'
    elif [[ $REPLY =~ ^[Ww]$ ]]; then
        HOST='desktop-work'
    elif [[ $REPLY =~ ^[Oo]$ ]]; then
        HOST='desktop-office'
    else
        echo -e "${ERROR}Invalid choice. Please select 'D', 'W', or 'O'."
        continue
    fi
    
    echo -en "${INFO}Use the ${YELLOW}'$HOST'${RESET} host? [${GREEN}y${RESET}/${RED}n${RESET}]: "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        break
    fi
done

#---------------------------#
#   Recap of user choices   #
#---------------------------#

echo -e "\n${BLUE}═══════════════════════════════════════${RESET}"
echo -e "${INFO}Installation Summary:"
echo -e "    Username:   ${YELLOW}$username${RESET}"
echo -e "    Host:       ${YELLOW}$HOST${RESET}"
echo -e "${BLUE}═══════════════════════════════════════${RESET}\n"

#-----------------------#
#   Last Confirmation   #
#-----------------------#

echo -en "${INFO}You are about to build the system for host ${YELLOW}'$HOST'${RESET}. Proceed? [${GREEN}y${RESET}/${RED}n${RESET}]: "
read -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${INFO}Installation cancelled."
    exit 0
fi

#---------------------#
#   Change username   #
#---------------------#

echo -e "${INFO}Changing username from ${YELLOW}${CURRENT_USERNAME}${RESET} to ${GREEN}${username}${RESET}"
find ./hosts ./modules flake.nix -type f -exec sed -i -e "s/${CURRENT_USERNAME}/${username}/g" {} +
echo -e "${OK}Username updated successfully"

#------------------------------#
#   Prepare the environment   #
#------------------------------#

echo -e "${INFO}Preparing the environment"

## Create common directories
for dir in ~/Downloads ~/Documents ~/Pictures ~/Projects ~/Music; do
    if [ ! -d "$dir" ]; then
        echo -e "${INFO}Creating folder: ${MAGENTA}${dir}${RESET}"
        mkdir -p "$dir"
    fi
done

## Get the hardware configuration
if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    echo -e "${ERROR}${MAGENTA}/etc/nixos/hardware-configuration.nix${RESET} not found!"
    echo -e "${INFO}Please run ${YELLOW}'nixos-generate-config'${RESET} first to generate hardware configuration."
    exit 1
fi

echo -e "${INFO}Copying ${MAGENTA}/etc/nixos/hardware-configuration.nix${RESET} to ${MAGENTA}./hosts/${HOST}/${RESET}"
cp /etc/nixos/hardware-configuration.nix hosts/${HOST}/hardware-configuration.nix
echo -e "${OK}Hardware configuration copied"

#------------------#
#   Installation   #
#------------------#

echo -e "\n${INFO}Starting system build... this may take a while."
echo -e "${MAGENTA}────────────────────────────────────────${RESET}\n"

if sudo nixos-rebuild switch --flake .#${HOST}; then
    echo -e "\n${MAGENTA}────────────────────────────────────────${RESET}"
    echo -e "${OK}System build completed successfully!"
    echo -e "${INFO}You can now reboot to apply the configuration"
    echo -e "${INFO}Use ${YELLOW}'sudo reboot'${RESET} to restart your system"
else
    echo -e "\n${ERROR}System build failed!"
    echo -e "${INFO}Please check the error messages above"
    exit 1
fi
