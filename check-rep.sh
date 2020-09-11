#!/usr/bin/env bash

####################################
# karl.schindler@gmx.at  2020-09-01
####################################
# script with basic checks
#   if name resolution is working
#   if internet is accessible    
#   if sw repository is reachable
#   if required packages are installed
#   if ports are open
# Return codes:
# 1 not root/Superuser
# 2 repository not reacahble
# 3 required packages not installed
# 4 not authorized
# 5 file not found
# 6 required ports not open
# 7 Operating System not supported
# 8 Wrong language settings
# 9 Debian Source = CD
# 127 other



# The following function prints a text using custom color
# -c or --color define the color for the print. See the array colors for the available options.
# -n or --noline directs the system not to print a new line after the content.
# Last argument is the message to be printed.

cecho () {
 
    declare -A colors;
    colors=(\
        ['black']='\E[0;30m'\
        ['red']='\E[0;31m'\
        ['green']='\E[0;32m'\
        ['yellow']='\E[0;33m'\
        ['blue']='\E[0;34m'\
        ['magenta']='\E[0;35m'\
        ['cyan']='\E[0;36m'\
        ['white']='\E[0;37m'\
        ['orange']='\E[0;33m'\
        ['purple']='\E[0;35m'\
        ['BrightGray']='\E[0;90m'\
        ['BrightRed']='\E[0;91m'\
        ['BrightGreen']='\E[0;92m'\
        ['BrightBlue']='\E[0;94m'\
        ['BrightMagenta']='\E[0;95m'\
        ['BrightCyan']='\E[0;96m'\
        ['BrightWhite']='\E[0;97m'\
    );
 
    local defaultMSG="No message passed.";
    local defaultColor="black";
    local defaultNewLine=true;
 
    while [[ $# -gt 1 ]];
    do
    key="$1";
 
    case $key in
        -c|--color)
            color="$2";
            shift;
        ;;
        -n|--noline)
            newLine=false;
        ;;
        *)
            # unknown option
        ;;
    esac
    shift;
    done

    message=${1:-$defaultMSG};   # Defaults to default message.
    color=${color:-$defaultColor};   # Defaults to default color, if not specified.
    newLine=${newLine:-$defaultNewLine};
 
    echo -en "${colors[$color]}";
    echo -en "$message";
    if [ "$newLine" = true ] ; then
        echo;
    fi
    tput sgr0; #  Reset text attributes to normal without clearing screen.
 
    return;
}
 
warning () {
 
    cecho -c 'yellow' "$@";
}
 
error () {
 
    cecho -c 'red' "$@";
}
 
information () {
 
    cecho -c 'BrightBlue' "$@";
}

success () {
 
    cecho -c 'BrightGreen' "$@";
}

function GET_DEFAULT_INT {
    _interface="$(route | awk '/default/ { print $8 }')"
    _DEFAULT_INT=""
    if [[ $_interface == "" ]] ; then
        _interface="$(route | awk '/^0.0.0.0/ { print $8 }')"
        #error "could not determine Deafult Interface"
        
        if [[ $_interface == "" ]] ; then
            warning "could not determine Deafult Interface"
            _DEFAULT_INT=""
        else
         _DEFAULT_INT=$_interface
        
        fi    
    else
         _DEFAULT_INT=$_interface
    fi
    if [[ $_DEFAULT_INT == "" ]] ; then
        warning "could not determine Default Interface"
        _DEFAULT_INT="n/a"
    fi    
}
function GET_DEFAULT_GW {
    _interface="$(netstat -rn | awk '/default/ { print $8 }')"
    _DEFAULT_INT=""
    if [[ $_interface == "" ]] ; then
        _interface="$(netstat -rn | awk '/^0.0.0.0/ { print $8 }')"
        #error "could not determine Deafult Interface"
        
        if [[ $_interface == "" ]] ; then
            warning "could not determine Deafult Interface"
            _DEFAULT_INT=""
        else
         _DEFAULT_INT=$_interface
        
        fi    
    else
         _DEFAULT_INT=$_interface
    fi
    if [[ $_DEFAULT_INT == "" ]] ; then
        warning "could not determine Default Interface"
        _DEFAULT_INT="n/a"
    fi    
}
function SCRIPT_ABORT {
    
    error "${_exit_message}  Aborting ..."
    exit $_exit_code
}

if [ "$EUID" -ne 0 ]
  then
  declare -i _exit_code=1
  declare _exit_message="Please run as root or sudo!"
  SCRIPT_ABORT #$_exit_code $_exit_message 
  #exit
fi
script="${0##*/}"
#exec 2>&1 | tee -a /var/log/${script} 
#exec 1 2>&1 | tee -a /var/log/$script.log
#exec &>> /dev/udp/192.168.12.2/12345 2>&1 |tee -a /var/log/$script.log
set -e

stagelog="/var/log/c4sam_install_stage.log"
clear
_REQ_SW="true"
_REQ_PORTS="true"
_REQ_OS="debian"
_REQ_OS_VER="9"
_REQ_LANG="en_US.UTF-8"
#_REPOSITORY="hal9000tng.homelinux.net"
_REPOSITORY="gitlab.c4sam.com"
_PORTS="22 443 6000"
# required Software packages
_REQUIREMENTS="route dig traceroute git curl netstat ntpstat" #docker sohuold be installed with cockpit/minion install script

#GET_DEFAULT_INT

_OS="$(grep "^ID" /etc/*-release | cut -d"=" -f2-)"
_OS_VER="$(grep "^VERSION_ID" /etc/*-release | cut -d"=" -f2- | awk '{gsub(/\"|\;/,"",$1)}1')"
_OS_NAME="$(grep "^NAME" /etc/*-release | cut -d"=" -f2-)"
_DEFAULT_GW="$(netstat -rn | awk '/^0.0.0.0/ { print $2 }')"
_FQDN="$(hostname -f)"
#_DEFAULT_INT="$(route | awk '/default/ { print $8 }')"
_CWD="$(pwd)"

function PRINT_HASH {
    cecho -c 'yellow' "############################################################################################"
}

function CHECK_REPOSITORY_ALIVE {
    information "Check Connectivity to Host"
    ping -c1 -W1 -q $1 &>/var/log/${script}.log
    status=$( echo $? )
    if [[ $status == 0 ]] ; then
        success "$1 is alive"
        #Connection success!
    else
        #error "$1 is down"
        declare -i _exit_code=2
        declare _exit_message="C4SAM Software Repository not reachable"
        SCRIPT_ABORT 
        #exit 1
        #Connection failure
    fi
}
function CHECK_LANGUAGE_SETTING {
    if [[ "${LANG}" != "${_REQ_LANG}" ]] ; then
        declare -i _exit_code=8
        declare _exit_message="Wrong Language settings ${LANG}, must be ${_REQ_LANG} "
        SCRIPT_ABORT
    else
        success "Check Language settings passed ${LANG}"    
    fi         
}
function CHECK_PKG {
    #command -v $1 /var/log/${script}.log 2>&1 || { echo >&2 "I require $1 but it's not installed.  Aborting."; exit 1; }
    _REQ_SW="true"
    if (command -v $1) >> /var/log/${script}.log; then
        #cecho -c 'green' "$1 is installed"
        success "$1 is installed"
    else
        error "$1 is not installed"
        _REQ_SW="false"
        INSTALL_PACKAGES $1
        #
       
    #exit 1
    fi        
}

function CHECK_PACKAGES {
    information "Checking Software Packages"
    for i in $_REQUIREMENTS; do
        #echo "Checking Software Package ${i} "
        CHECK_PKG $i
    done 
}

function CHECK_PORT {
    port=$1
    #if (exec 3<>/dev/tcp/${_REPOSITORY}/${port}) 2> /var/log/${script}.log; then
    if (exec 1<>/dev/tcp/${resolvedIP}/${port}) 2>> /var/log/${script}.log; then
        success "${port} is open"
    else
        error 'red' "${port} is closed"
        _REQ_PORTS="false"
    fi
}

function INSTALL {
    chmod 754 install_${_install_type}.sh &&./install_${_install_type}.sh && rm install_${_install_type}.sh
}

function DL_INSTALLER {
    set +e
        information "download installer for ${_install_type} using Token ${TOKEN}"
    if [[ $_install_type == "minion" ]]; then
        declare -i _exit_code=127
        declare _exit_message="Not implemented yet"
        SCRIPT_ABORT
    elif [[ $_install_type == "cockpit" ]]; then
        _source="https://gitlab.c4sam.com/api/v4/projects/46/repository/files/install_cockpit.sh/raw?ref=master"
    response="$(curl --request GET --header "PRIVATE-TOKEN: ${TOKEN}" -sL -w "%{http_code}" -o install_${_install_type}.sh ${_source})"
    #information "Command: curl --request GET --header \"PRIVATE-TOKEN: ${TOKEN}\" -sL -w \"%{http_code}\" -o install_${_install_type}.sh '${_source}' "
    fi
    case "$response" in
        200) success "Download Success" && INSTALL ;;
        301) information $response ;;
        #304) information "Received: HTTP $response (file unchanged) ==> $url\n" ;;
        401) error "Not Authorized" && exit 4;;
        404) error "file not found" && exit 5;;
          *) information  "Received: HTTP $response " ;;
    esac
    set -e

}

function ENTER_TOKEN {
    #cecho -c 'BrightGreen' "############################";
    PRINT_HASH
    read -p $'\e[0;37mEnter your Repository Access Token    :\e[1;33m ' TOKEN
    PRINT_HASH
    #echo $'\e[0;92m############################'
    cecho -c 'BrightWhite' "Repository Access Token       =    ${TOKEN}"
    PRINT_HASH
    #cecho -c 'BrightGreen' "############################"
    read -p $'\e[0;31mConfirm (Y) change Token (C) Exit (N)? (Y/N/C): \e[1;33m ' confirm
    case $confirm in
        y|Y )
            DL_INSTALLER $TOKEN;;
        c|C )
            ENTER_TOKEN ;;   
        * )
            echo "Exit without installing"
            echo $'\e[0m'
            exit
            ;;
    esac

}

function PROCEED {
    if [[ $_install_type == "minion" ]]; then
        declare -i _exit_code=127
        declare _exit_message="Not implemented yet"
        SCRIPT_ABORT
    fi    
    PRINT_HASH
    #echo $'\e[0;92m############################';
    echo ""
    echo "to download the installer you need a valid Access Token!"
    echo "(your personal access token based on your repository account)"
    echo ""
    echo "to proceed with downloaded installer you need a valid Cockpit ID and Token!"
    echo "(Cockpit Token is issued per licensed cockpit instance)"
    echo ""
    echo "Report any errors to support@c4sam.com"
    echo ""
    echo "Proceed with installation?"
    echo ""

    read -p $'\e[0;31mConfirm (Y) Exit (N)? (Y/N): \e[1;33m ' confirm
    case $confirm in
        y|Y )
            ENTER_TOKEN ;;
        * )
            echo "Exit without installing"
            echo $'\e[0m'
            exit
            ;;
    esac

}
function SELECT_INSTALLATION {
        read -p $'\e[0;34mSelect Installation ? (C)ockpit  (M)inion (E)xit? (C/M/E): \e[1;33m ' _select
        case $_select in
            c|C )
                _install_type="cockpit" ;;
            m|M )
                _install_type="minion" ;;
            e|E )
                echo "exit"
                echo $'\e[0m' 
                exit ;;        
            * )
                echo "exit"
                echo $'\e[0m'
                ;;
        esac
}
function CHECK_UPDATES {
    
    information "Update Package Information"
    apt -y update >  /var/log/${script}.log 2>&1
    _no_updates=`apt list --upgradeable 2>> /var/log/${script}.log | grep -v -e '^[[:space:]]*$' | grep -v 'Listing'| wc -l`
    information "${_no_updates} Updates available"
    if [[ $_no_updates -gt 0 ]]; then
    read -p $'\e[0;31mProceed updating packages? (Y) No (N)? (Y/N): \e[1;33m ' confirm
        case $confirm in
            y|Y )
                apt -y upgrade ;;
            * )
                echo "Proceed without updating"
                echo $'\e[0m'
                ;;
        esac
    fi    
}
function INSTALL_PACKAGE {
    _package=$1
    echo "Installation procedure for ${_package}"
    case $_package in
        docker )
            echo "need to install package ${_package} with special function" ;;
        dig )
            echo "${_package} need to install package dnsutils " 
            apt install -y dnsutils;;    
        netstat|route )
            echo "${_package} need to install package net-tools " 
            apt install -y net-tools;;
        * )
            echo "install package ${_package}" 
            apt install -y $_package ;;
    esac
    CHECK_PACKAGES        
}
function INSTALL_PACKAGES {
    _package=$1
    information "Install Package ${_package}"
    
    read -p $'\e[0;31mInstall required package? (Y) No (N)? (Y/N): \e[1;33m ' confirm
        case $confirm in
            y|Y )
                #echo "install package ${_package} " 
                INSTALL_PACKAGE $1;;
            * )
                echo "Proceed without installing"
                _REQ_SW="false"
                echo $'\e[0m'
                ;;
        esac
}
function CHECK_DEBIAN_SOURCES {
    _cd_rom_source=`cat /etc/apt/sources.list |grep -v "#" |grep "cdrom:"|wc -l`
    if [[ $_cd_rom_source -gt 0 ]]; then
        declare -i _exit_code=9
        declare _exit_message="Package Source is CDROM, change Debian installation source in file /etc/apt/sources.list to an online Source!"
        SCRIPT_ABORT
    else
        success "Check Installation Source passed"    
    fi     
}

function GET_PUBLIC_IP {
    set +e  ### dont exit on returncode > 0
    myWanIP=`dig +short myip.opendns.com @resolver1.opendns.com`
    if [[ $? -gt 0 ]]; then
        error "Public IP could not be determind"
    else    
        information "Public IP is ${myWanIP}"
    fi
    set -e    
}
function main() {
    SELECT_INSTALLATION
    PRINT_HASH
    information "Checking Installation Source"
    CHECK_DEBIAN_SOURCES

    PRINT_HASH
    information "Checking language settings"
    CHECK_LANGUAGE_SETTING

    PRINT_HASH
    information "Checking Software Updates"
    CHECK_UPDATES    

    PRINT_HASH
    CHECK_PACKAGES
    
    PRINT_HASH
    if [[ $_REQ_SW == "true" ]] ; then
        success "required software installed"
    else
        declare -i _exit_code=3
        declare _exit_message="not all required packages installed, exiting. "
        SCRIPT_ABORT
        # error "not all required packages installed, exiting."
        # exit 3
    fi
    GET_DEFAULT_INT
    GET_DEFAULT_INT
    PRINT_HASH
    information "Hostname: ${_FQDN}" 
    information "Operating System: ${_OS} , Version: ${_OS_VER}" 
    information "Default Interface: ${_DEFAULT_INT}, Default GW: ${_DEFAULT_GW}"
    # get public IP
    GET_PUBLIC_IP
    
    PRINT_HASH
    information "Checking Name Resolution"
    # Checking for the resolved IP address from the end of the command output. Refer
    # the normal command output of nslookup to understand why.
    resolvedIP=$(nslookup "${_REPOSITORY}" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)

    # Deciding the lookup status by checking the variable has a valid IP string
    [[ -z "$resolvedIP" ]] && error "${_REPOSITORY}" lookup failure || success "${_REPOSITORY} resolved to ${resolvedIP}"

    #traceroute $resolvedIP

    #ping -c1 -W1 -q $resolvedIP && echo "${resolvedIP} is reachable" || echo "${resolvedIP} is down"
    PRINT_HASH

    CHECK_REPOSITORY_ALIVE $resolvedIP

    PRINT_HASH

    

    information "Checking Ports"
    for i in $_PORTS; do
        #echo "Check Port ${i} on ${_REPOSITORY}"
        CHECK_PORT $i
    done
    PRINT_HASH
    if [[ $_REQ_PORTS == "true" ]] ; then
        success "required ports open"
    else
        declare -i _exit_code=6
        declare _exit_message="not all required ports are open, exiting"
        SCRIPT_ABORT
        # error "not all required ports are open, exiting"
        # exit 1
    fi

    

    if [[ $_OS_VER -ge $_REQ_OS_VER ]] && [[ $_OS == "${_REQ_OS}" ]] ; then
        success "Operating System supported"
    else
        declare -i _exit_code=7
        declare _exit_message="Operating System ${_OS} ${_OS_VER} not supported, ${_REQ_OS} ${_REQ_OS_VER} required, exiting. "
        SCRIPT_ABORT
        # error "Operating System ${_OS} ${_OS_VER} not supported, ${_REQ_OS} ${_REQ_OS_VER} required, exiting."
        # exit 1
    fi

PROCEED
}

main 2>&1 | tee -a /var/log/${script}.log
cd $_CWD
exit 0