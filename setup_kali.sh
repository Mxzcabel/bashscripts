#!/bin/bash
#------------------------------------------------------------------
#- Script by: mxzcabel
#- https://github.com/mxzcabel
#- Date: 26/03/14
#- Last update date: 26/03/26
#- Description: This script is for setting basic configs for pentesting
#-------------- with Kali Linux Virtual Machine.
#-------------- Just a fun exercise to share bash scripts basics
#-------------- and programming skills.
#------------------------------------------------------------------
#
#---------/---------/------------/--------------/------------------
# TIMEZONE PARAMENTERS #
DEFAULTIMEZONE="America/Sao_Paulo"
TIMEZONE=$DEFAULTIMEZONE
OSZONEINFO="/usr/share/zoneinfo"
OSLOCALTIME="/etc/localtime"

# CUSTOM VARIABLES MAY CHOOSEN BY USER #
LABUSER="labuser"
LABGROUP="labwork"
LABTOOLS="/opt/labtools"
WORKSPACE="lab_workspace"
HOMEDIR=true
HOMELOCATION=/home/$LABUSER/$WORKSPACE

# SISTEM VERSION #
OSVERSION="kali-rolling"

# TEMPORARY FILES FOR SETUP #
TMPDIR="/tmp"
SETUPDIR="$TMPDIR/setup_kali"

# ALL FILES CREATED INSIDE TEMPORARY FILES #
PINGFILE="$SETUPDIR/ping.log"
UPDATEFILE="$SETUPDIR/update_system.log"
TOOLSFILE="$SETUPDIR/tools_system.log"
USERFILE="$SETUPDIR/user.log"
GROUPFILE="$SETUPDIR/group.log"
APTFILE="$SETUPDIR/apt.log"

# FOR FINAL LOGGING (OPTIONAL)
KALIFLAG="$SETUPDIR/flag_kali.txt"
OUTPUTFILE="$SETUPDIR/setup_log.txt"

# DEFAULT TOOLS TO INSTALL IF NONE ARE DEFINIED BY THE USER #
TOOLSTOINSTALL=("zaproxy" "whatweb" "metasploit-framework" "python3" "python3-pip" "git" "vim" "jq" "fail2ban" "ufw" "ssh")

displayHelp() {
	printf "%s\n"
	echo "Script to setup my system lab in Kali Linux"
	printf "%s\n"
	echo "options:"
	echo "-h, --help		      	display this help"
	echo "-l, --labdir			which directory the lab should be"
	echo "-t, --timezone	  	  	which timezone the system should use"
	echo "-d, --workspace	  	  	which directory the workspace should be"
	echo "-u, --user		        which user the lab should use"
	echo "-g, --group		        which group the lab should use"
	echo "-r, --root          	  	the workspace will be set at root instead of a home user"
	echo "-p, --packages		  	define custom tools to install."
	echo "				 use commas between packages to set ones within dash"
}

# Verify environment before starting
  function AllNeededChecked() {
     OS=$(awk '{print}' /etc/os-release | sed -n "s/.*\($OSVERSION\)/\1/Ip")
     [[ $OS != $OSVERSION ]] && printf "%s" "Aborting script... This system is not Kali." && return 1

     ! command -v apt &>/dev/null && printf         '%s' "Aborting script... apt package manager was not found." && return 1
     ! command -v sed &>/dev/null && printf         '%s' "Aborting script... sed package was not found." && return 1
     ! command -v awk &>/dev/null && printf         '%s' "Aborting script... awk binary was not found." && return 1
     ! command -v tee &>/dev/null && printf         '%s' "Aborting script... tee binary was not found." && return 1
     ! command -v readlink &>/dev/null && printf    '%s' "Aborting script... readlink binary was not found." && return 1

    return 0
}

# Track all terminal output to a file
outputLog () {
    tee -a $OUTPUTFILE
}

# Print defined variables, it identify root privileges, adjusts home location and verify WORKSPACE AND LABTOOLS to not use /home/ directory.
# and before starting with startSetup(), output results in OUTPUTFILE as well
preStartup () {
    [[ $WORKSPACE =~ "/home/" || $LABTOOLS =~ "/home/" ]] && printf "%s" "Caution: Do not set a home directory. This will be set automatically by the script for the WORKSPACE. Meanwhile, LABTOOLS directory should not be put at an user's folder." && return 1
    [[ ${TOOLSTOINSTALL[@]} == "" ]] && printf "%s" "Caution: the packages list is empty." && return 1
    [[ $EUID -ne 0 ]] && printf "%s" "Aborting script... needs superuser priviliges to run." && return 1

    mkdir -p $SETUPDIR
    : > $OUTPUTFILE
    exec > >(outputLog) 2>&1

    printf "%s\n\e[33m"
    printf "%s\e[32m"
    printf "%s\e[37m\n" "-> DEFINED LABTOOLS DIRECTORY:" "$LABTOOLS"
    printf "%s\e[32m"
    printf "%s\e[37m\n" "-> DEFINED TIMEZONE:" "$TIMEZONE"
    printf "%s\e[32m"
    printf "%s\e[37m\n" "-> DEFINED LABUSER:" "$LABUSER"
    printf "%s\e[32m"
    printf "%s\e[37m\n" "-> DEFINED LABGROUP:" "$LABGROUP"
    printf "%s\e[32m"
    printf "%s\e[37m\n" "-> DEFINED TOOLS:"
    printf "%s " "${TOOLSTOINSTALL[@]}"
    printf "%s\e[37m\n"

    if [[ $HOMEDIR == false ]] ; then
        printf "%s\e[32m"
        printf "%s\e[37m\n" "-> DEFINED WORKSPACE PATH:" "/$WORKSPACE"
        printf "%s\e[33m\n"
        printf "%s\e[37m\n" "! WORKSPACE IS SET AS SYSTEM DIRECTORY"

    else
        HOMELOCATION=/home/$LABUSER/$WORKSPACE
        printf "%s\e[32m"
        printf "%s\e[37m\n" "-> DEFINED WORKSPACE PATH:" "$HOMELOCATION"
    fi

    printf "%s\n"
    printf "%s" "Is everything as expected? [Y/n]"
    read -r answer
    [[ $answer == "y" || $answer == "Y" ]] && startSetup

    printf "%s\n" "Aborting script..."
    rm -r $SETUPDIR
    exit 1
}

# Check if any paramenters defined by the user exists #
checkParamenters() {
    [[ $# -eq 0 ]] && printf "%s\n" "No arguments defined. Using default options..." && preStartup
    [[ $# -gt 0 ]] && paramenters $@
}

# Any custom paramenter defined by the user are settle here #
paramenters() {
    # All the flags this script will accept
    expectArgs=("-h" "--help" "-l" "--labdir=" "-t" "--timezone=" "-d" "--workspace=" "-u" "--user=" "-g" "--group=" "-r" "--root" "-p" "--packages=")
    # Start counting to always catch the string after choosen paramenter.
    # Using shift was another option, but I wanted to explore other possibilities.
    opt=1

    for argument in "$@" ; do
        opt=$((opt + 1))
        [[ $opt -eq 2 ]] && [[ ! $argument =~ '-' ]] && printf "Flag is not valid. Aborting..." && exit 1

        case $argument in

            # "-h" | "--help="
            ${expectArgs[0]} | ${expectArgs[1]})
                # Display full help
                #
                displayHelp
                exit 0
                ;;

            # "-l" | "--labdir="
            ${expectArgs[2]} | ${expectArgs[3]}*)
                # LABTOOLS is expected to be within system files
                #
                LABTOOLS=$(! defineArgs $argument ${expectArgs[2]} ${expectArgs[3]} ${!opt}) && blankMessage
                ;;

            # "-t" | "--timezone="
            ${expectArgs[4]} | ${expectArgs[5]}*)
                # TIMEZONE can be any zonefile inside /usr/share/zoneinfo/
                #
                TIMEZONE=$(! defineArgs $argument ${expectArgs[4]} ${expectArgs[5]} ${!opt}) && blankMessage
                ;;

            # "-u" | "--user"
            ${expectArgs[8]} | ${expectArgs[9]}*)
                # USER  TO BE CREATED USING "useradd"
                #
                valid_opt=$(validateArg ${!opt})
                LABUSER=$(! defineArgs $argument ${expectArgs[8]} ${expectArgs[9]} ${valid_opt}) && blankMessage
                ;;

            # "-g" | "--group="
            ${expectArgs[10]} | ${expectArgs[11]}*)
                # GROUP TO BE CREATED USING "groupadd"
                #
                valid_opt=$(validateArg ${!opt})
                LABGROUP=$(! defineArgs $argument ${expectArgs[10]} ${expectArgs[11]} ${valid_opt}) && blankMessage
                ;;

            # "-d" | "--workspace="
            ${expectArgs[6]} | ${expectArgs[7]}*)
                # WORKSPACE is expected to be inside HOMEDIR
                #
                WORKSPACE=$(! defineArgs $argument ${expectArgs[6]} ${expectArgs[7]} ${!opt}) && blankMessage
                ;;

            # "-r" | "--root"
            ${expectArgs[12]} | ${expectArgs[13]})
                # HOMEDIR is expected to be "true" as default
                # otherwise, HOMEDIR can be set inside the system files as "false"
                #
                HOMEDIR=false
                ;;
            ${expectArgs[14]} | ${expectArgs[15]}*)
                # Look for packages between commas and append them to array,
                # in this case: TOOLSTOINSTALL
                #
                TOOLSTOINSTALL=()
                packages=$(! defineArgs $argument ${expectArgs[14]} ${expectArgs[15]} ${!opt}) && blankMessage
                # Do not allow spaces after commas!
                # analyze which input and apply to both different critera
                #
                local spaces=$((opt + 1))

                if [[ $argument == ${expectArgs[14]} ]] ; then
                    [[ ! "${!spaces}" ]] || [[ "${!spaces}" =~ ^"-" ]] && valid_flag=true

                else
                    [[ ! ${!opt} ]] && [[ ! "${!spaces}" =~ ^"-" ]] && [[ ! "${packages}" =~ ^"-" ]] && valid_flag=true
                fi

                if [[ $valid_flag == true && "$packages" =~ ^[a-zA-Z0-9,_-]+$ ]] ; then
                    packages=$(printf "%s" "$packages" | tr -d ' ')
                    IFS=',' read -r -a TOOLSTOINSTALL <<< "${packages[0]}"

                else
                    printf "%s\n" "Something is wrong while parsing packages..."
                    printf "%s\n" "Could be packages separate between spaces instead of commas or there is not allowed special characters included."
                    printf "%s" "Aborting..."
                    exit 1
                fi
                ;;
            # none
            -*)

                printf "%s" "One or more commands are not valid. Aborting..."
                exit 1
                ;;
        esac
    done
    preStartup
}

# Very important to indentify invalid characters
# and to validate paramenters from args
  function defineArgs() {
    local option=${1#*$3}
    local alnum="[a-zA-Z0-9]"
    # Any one word with one dash go here
    if [[ $1 == $2 ]] ; then
        [[ ! $4 =~ $alnum || $4 == "" ]] && return 1
        printf "%s" $4
    fi
    # Any two dashes, extended words, go here
    if [[ $1 =~ $3 ]] ; then
        [[ ! $option =~ $alnum || $option == "" ]] && return 1
        printf "%s" $option
    fi

    return 0
}

# Verify blank or non-alphanumerical digits in paramenter()
    function blankMessage() {
    printf "%s" "Some flag's paramenter are blank or have only non-alphanumerical digits. Aborting..."
    exit 1
}

# Do not allow LABUSER or LABGROUP start with a non-alphanumerical character.
  function validateArg() {
    printf "%s" "$1" | tr -cd '[:alnum:]'
}

# Start after all paramenters sanity check, if they are not default
# in paramenters ()
function startSetup () {
    checkNetwork
    setTimezone
    catOSInfo
    updateSystem
    createUserGroups
    setDirsPerm
    finalSetup

    exit 0
}

# Check internet connection before installing TOOLS
function checkNetwork () {
    printf "%s\e[32m"
    printf "%s\n\e[34m" "Checking internet connection..."
    sleep 2
    ping -c 1 -q www.kali.org ; printf "%s\n" $? > $PINGFILE
    ping -c 1 -q 104.18.26.120 ; printf "%s\n" $? >> $PINGFILE
    ping -c 1 -q 1.1.1.1 ; printf "%s\n\e[32m" $? >> $PINGFILE
    [[ -z $(awk '/0/ {print}' $PINGFILE) ]] && printf "%s\e[31m" && printf "%s" "No network. Try again when online." && exit 2
    printf "%s\n\e[32m"
    printf "%s\n" "All right!"
}

# Change TIMEZONE only if it is not the default, not equal to default, or the TIMEZONE during swap results in an error
function setTimezone () {
    if [[ $(readlink -- $OSLOCALTIME) != $OSZONEINFO/$DEFAULTIMEZONE || $TIMEZONE != $DEFAULTIMEZONE ]] ; then

        if [[ $(readlink -- $OSLOCALTIME) == $OSZONEINFO/$TIMEZONE ]] ; then
            printf "%s\e[33m\n"
            printf "%s\n" "TIMEZONE is the same as the one already set. Keeping it."
            printf "%s\e[37m"
        else
            printf "%s\n\e[32m"
            printf "%s\e[31m\n" "Defining timezone $TIMEZONE..."
            ln -sf $OSZONEINFO/$TIMEZONE /etc/localtime
            printf "%s\e[34m"
            printf "%s %s %s %s %s" $(date)
        fi

        if [[ ! -e $OSLOCALTIME ]] ; then
            printf "%s\n" "-> Aborting... timezone was not possible to set. May be something wrong with set flag."
            printf "%s" "-> Setting timezone again within script's default"
            ln -sf $OSZONEINFO/$DEFAULTIMEZONE /etc/localtime
            exit 1
        fi

    else
        printf "%s\e[33m\n"
        printf "%s\n" "TIMEZONE is the same as default. Keeping it."
        printf "%s\e[37m"

    fi
    sleep 3
}

# Print the timestamp from the start and final of the script
function getTimestamp () {
    printf "%s\n\e[32m"
    printf "%s\n\e[34m" "Timestamp $1:"
    printf "%s\t" $(date +"%Y-%m-%d %H:%M:%S")
    printf "%s\n"
}

# Print the system version at the start and final of the script
function getSysVersion () {
    printf "%s\n\e[32m"
    printf "%s\n\e[34m" "The system current version:"
    printf "%s\n" $(awk 'BEGIN{IGNORECASE=1};/version=/ {print}' /etc/os-release | sed "s/[A-Za-z].//g")
}

# Print birth of the system before starting
function getSysBirthday {
    printf "%s\n\e[32m"
    printf "%s\n\e[34m" "The system birth date:"
    printf "%s\t" $(stat / | awk 'BEGIN{IGNORECASE=1};/birth:/ {print}' | sed "s/[A-Za-z].//g")
}

# Get system's birth date and version
function catOSInfo () {
    getTimestamp "on start"
    getSysVersion
    getSysBirthday
    printf "%s\n"
    sleep 3
}

# Start updating system and install TOOLS
function updateSystem () {
    printf "%s\n\e[32m"
    printf "%s\n\e[37m" "Updating system..."
    script -O $UPDATEFILE -qc "apt update"
    script -a $UPDATEFILE -qc "apt upgrade -y"
    script -a $UPDATEFILE -qc "apt autoremove -y"
    script -a $UPDATEFILE -qc "apt clean"

    printf "%s\n"
    apt list ${TOOLSTOINSTALL[@]} >& $TOOLSFILE
    sed -e "/Listing.../Id;/WARNING.*/Id;/^$/d" -i $TOOLSFILE
    printf "%s\e[32m"
    printf "%s\n\e[37m" "List of Tools:"
    awk '{print $0}' $TOOLSFILE
    printf "%s\e[31m"
    sleep 2

    # If some TOOL was not installed, abort
    [[ $(awk 'END {print NR}' $TOOLSFILE) -ne ${#TOOLSTOINSTALL[@]} ]] && printf "%s" "Something is wrong... one or more packages could not be found. Verify typos or former package names occurences." && exit 2

    printf "%s\n\e[33m"
    apt install -y ${TOOLSTOINSTALL[@]} ; printf "%s" $? > $APTFILE
    verifyAPTInstall $APTFILE
}

# Create LABUSER and LABGROUP
function createUserGroups () {
    printf "%s\n\e[32m"
    printf "%s\n\e[37m" "Creating user and group..."
    groupadd $LABGROUP ; printf "%s" $? > $GROUPFILE
    verifyCreation $GROUPFILE $LABGROUP

    printf "%s\e[37m"
    useradd -m -d /home/$LABUSER -s /bin/zsh -g $LABGROUP $LABUSER ; printf "%s" $? > $USERFILE
    verifyCreation $USERFILE $LABUSER
    printf "%s\n"
}

# Only show LABUSER or LABGROUP creation's message when relative
function verifyCreation () {
    printf "%s\e[34m"
    [[ $(awk '{print}' $1) -eq 0 ]] && printf "%s" "$2 has been added!"
    printf "%s\n"
}

# If APT got some error, abort script
function verifyAPTInstall () {
    printf "%s\n\e[31m"
    [[ $(awk '{print}' $1) -ne 0 ]] && printf "%s" "Something is wrong... one or more package could not be installed. Verify apt availability or internet connection." && exit 2
}

# Set permissions of made directories
function setDirsPerm () {
    printf "%s\n\e[32m"
    printf "%s\n\e[34m" "Creating directories..."
    printf "%s\e[37m%s\e[34m\n" "LAB:" "$LABTOOLS"

    mkdir -p /$LABTOOLS
    chown -R root:$LABGROUP /$LABTOOLS
    chmod 660 /$LABTOOLS

    chown -R $LABUSER:$LABGROUP $SETUPDIR

    if [[ $HOMEDIR == true ]] ; then
        printf "%s\e[37m%s\n" "WORKSPACE:" "$HOMELOCATION"

        mkdir -p $HOMELOCATION
        chown -R $LABUSER:$LABGROUP $HOMELOCATION
        chmod 755 $HOMELOCATION

    else
        printf "%s\e[37m%s\n" "WORKSPACE:" "/$WORKSPACE"

        mkdir -p /$WORKSPACE
        chown -R $LABUSER:$LABGROUP /$WORKSPACE
        chmod 770 /$WORKSPACE

    fi

    sleep 2
}

function finalSetup () {
    printf "%s\n\e[33m"
    printf "%s\n" "Done! :D"
    printf "%s\n" "You may want to restart your computer before using the lab."

    getTimestamp "on final"
    getSysVersion

    # Eliminate colors and ctrl escapes
    sed -e 's/\x1b//g;s/\r//g' -i $OUTPUTFILE
    sed 's/\[[0-90-9;]*[mK]//g' -i $OUTPUTFILE

    if [[ $HOMEDIR == true ]]; then
        cp --preserve=timestamps $TOOLSFILE $OUTPUTFILE -t $HOMELOCATION
    else
        cp --preserve=timestamps $TOOLSFILE $OUTPUTFILE -t /$WORKSPACE
    fi

    rm -r $SETUPDIR
}

AllNeededChecked && checkParamenters "$@"

