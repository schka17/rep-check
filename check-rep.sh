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
_REQ_SW="true"
_REQ_PORTS="true"
_REQ_OS="debian"
_REQ_OS_VER="9"
#_REPOSITORY="hal9000tng.homelinux.net"
_REPOSITORY="gitlab.c4sam.com"
_PORTS="22 443 6000"
# required Software packages
_REQUIREMENTS="dig traceroute git curl docker netstat"

GET_DEFAULT_INT

_OS="$(grep "^ID" /etc/*-release | cut -d"=" -f2-)"
_OS_VER="$(grep "^VERSION_ID" /etc/*-release | cut -d"=" -f2- | awk '{gsub(/\"|\;/,"",$1)}1')"
_OS_NAME="$(grep "^NAME" /etc/*-release | cut -d"=" -f2-)"
_DEFAULT_GW="$(netstat -rn | awk '/^0.0.0.0/ { print $2 }')"
_FQDN="$(hostname -f)"
#_DEFAULT_INT="$(route | awk '/default/ { print $8 }')"


function PRINT_HASH {
    cecho -c 'yellow' "############################################################################################"
}

function CHECK_REPOSITORY_ALIVE {
    information "Check Connectivity to Host"
    ping -c1 -W1 -q $1 &>/dev/null
    status=$( echo $? )
    if [[ $status == 0 ]] ; then
        success "$1 is alive"
        #Connection success!
    else
        error "$1 is down"
        exit 1
        #Connection failure
    fi
}
function CHECK_PKG {
    #command -v $1 /dev/null 2>&1 || { echo >&2 "I require $1 but it's not installed.  Aborting."; exit 1; }
    if (command -v $1) > /dev/null; then
        #cecho -c 'green' "$1 is installed"
        success "$1 is installed"
    else
       error "$1 is not installed, setup cannot continue."
       _REQ_SW="false"
       #exit 1
    fi        
}

function CHECK_PORT {
    port=$1
    #if (exec 3<>/dev/tcp/${_REPOSITORY}/${port}) 2> /dev/null; then
    if (exec 1<>/dev/tcp/${resolvedIP}/${port}) 2> /dev/null; then
        success "${port} is open"
    else
        error 'red' "${port} is closed"
        _REQ_PORTS="false"
    fi
}

function INSTALL {
    chmod 754 install_cockpit.sh &&./install_cockpit.sh && rm install_cockpit.sh
}

function DL_INSTALLER {
    information "download installer using Token ${TOKEN}"
    response=$(curl --request GET --header "PRIVATE-TOKEN: ${TOKEN}" -sL -w "%{http_code}" -o install_cockpit.sh 'https://gitlab.c4sam.com/api/v4/projects/46/repository/files/install_cockpit.sh/raw?ref=master')
    case "$response" in
        200) success "Download Success" && INSTALL ;;
        301) information $response ;;
        #304) printf "Received: HTTP $response (file unchanged) ==> $url\n" ;;
        401) error "Not Authorized" && exit 1;;
        404) error "file not found" && exit 1;;
          *) information  "Received: HTTP $response " ;;
    esac
}

function ENTER_TOKEN {
    #cecho -c 'BrightGreen' "############################";
    PRINT_HASH
    read -p $'\e[0;37mEnter your Token    :\e[1;33m ' TOKEN
    PRINT_HASH
    #echo $'\e[0;92m############################'
    cecho -c 'BrightWhite' "Token       =    ${TOKEN}"
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
    PRINT_HASH
    #echo $'\e[0;92m############################';
    echo ""
    echo "to proceed you need a valid Customer ID and Token!"
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
PRINT_HASH
information "Hostname: ${_FQDN}" 
information "Operating System: ${_OS} , Version: ${_OS_VER}" 
information "Default Interface: ${_DEFAULT_INT}, Default GW: ${_DEFAULT_GW}"
# get public IP
myWanIP=`dig +short myip.opendns.com @resolver1.opendns.com`
#echo "Public IP is ${myWanIP}"
information "Public IP is ${myWanIP}"
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

information "Checking Software Packages"

for i in $_REQUIREMENTS; do
    #echo "Checking Software Package ${i} "
    CHECK_PKG $i
done 

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
    error "not all required ports are open, exiting"
    exit 1
fi

if [[ $_REQ_SW == "true" ]] ; then
    success "required software installed"
else
    error "not all required packages installed, exiting."
    exit 1
fi

if [[ $_OS_VER -ge $_REQ_OS_VER ]] && [[ $_OS == "${_REQ_OS}" ]] ; then
    success "Operating System supported"
else
    error "Operating System ${_OS} ${_OS_VER} not supported, ${_REQ_OS} ${_REQ_OS_VER} required, exiting."
    exit 1
fi

PROCEED


exit 0