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
        ['black']='\E[0;47m'\
        ['red']='\E[0;31m'\
        ['green']='\E[0;32m'\
        ['yellow']='\E[0;33m'\
        ['blue']='\E[0;34m'\
        ['magenta']='\E[0;35m'\
        ['cyan']='\E[0;36m'\
        ['white']='\E[0;37m'\
        ['orange']='\E[0;33m'\
        ['purple']='\E[0;35m'\
        ['lightGray']='\E[0;37m'\
        ['darkGray']='\E[0;30m'\
        ['lightGray']='\E[0;37m'\
        ['lightRed']='\E[0;31m'\
        ['lightGreen']='\E[0;32m'\
        ['lightBlue']='\E[0;34m'\
        ['lightPurple']='\E[0;35m'\
        ['lightCyan']='\E[0;37m'\
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
 
    cecho -c 'lightBlue' "$@";
}

success () {
 
    cecho -c 'green' "$@";
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
_REQ_OS_VER="10"
#_REPOSITORY="hal9000tng.homelinux.net"
_REPOSITORY="gitlab.c4sam.com"
_PORTS="22 443 6000"
# required Software packages
_REQUIREMENTS="dig traceroute git curl docker netstat "

GET_DEFAULT_INT

_OS="$(grep "^ID" /etc/*-release | cut -d"=" -f2-)"
_OS_VER="$(grep "^VERSION_ID" /etc/*-release | cut -d"=" -f2- | awk '{gsub(/\"|\;/,"",$1)}1')"
_OS_NAME="$(grep "^NAME" /etc/*-release | cut -d"=" -f2-)"
_DEFAULT_GW="$(netstat -rn | awk '/^0.0.0.0/ { print $2 }')"
_FQDN="$(hostname -f)"
#_DEFAULT_INT="$(route | awk '/default/ { print $8 }')"
information "Hostname: ${_FQDN} Operating System: ${_OS} , Version: ${_OS_VER}, Default Interface: ${_DEFAULT_INT}, Default GW: ${_DEFAULT_GW}"
# get public IP
myWanIP=`dig +short myip.opendns.com @resolver1.opendns.com`
#echo "Public IP is ${myWanIP}"
information "Public IP is ${myWanIP}"

# Checking for the resolved IP address from the end of the command output. Refer
# the normal command output of nslookup to understand why.
resolvedIP=$(nslookup "${_REPOSITORY}" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)

# Deciding the lookup status by checking the variable has a valid IP string
[[ -z "$resolvedIP" ]] && error "${_REPOSITORY}" lookup failure || success "${_REPOSITORY} resolved to ${resolvedIP}"

#traceroute $resolvedIP

#ping -c1 -W1 -q $resolvedIP && echo "${resolvedIP} is reachable" || echo "${resolvedIP} is down"


function CHECK_REPOSITORY_ALIVE {
    ping -c1 -W1 -q $1 &>/dev/null
    status=$( echo $? )
    if [[ $status == 0 ]] ; then
        success "$1 is reachable"
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

CHECK_REPOSITORY_ALIVE $resolvedIP

information "Checking Software Packages"

for i in $_REQUIREMENTS; do
    #echo "Checking Software Package ${i} "
    CHECK_PKG $i
done 

information "Checking Ports"
for i in $_PORTS; do
    #echo "Check Port ${i} on ${_REPOSITORY}"
    CHECK_PORT $i
done

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

if [[ $_OS_VER >= 10  ]] ; then
    success "Operating System supported"
else
    error "Operating System not supported, exiting."
    exit 1
fi
