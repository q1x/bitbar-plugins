#!/bin/bash
#
# <bitbar.title>SSH Tunnel manager</bitbar.title>
# <bitbar.version>v1.01</bitbar.version>
# <bitbar.author>Raymond Kuiper</bitbar.author>
# <bitbar.author.github>q1x</bitbar.author.github>
# <bitbar.desc>Finds hosts in ssh config file with dynamic tunnels defined and tries to find out the status for these tunnels. Clicking the tunnel toggles the tunnel status by killing the associated proces or starting a new ssh session in the background. Useful when used with FoxyProxy for jump hosts.</bitbar.desc>
# <bitbar.dependencies>openssh</bitbar.dependencies>
#

# Location of the parsed ssh config file
SSHCONF=~/.ssh/config

# Function to notify the user via Aple Script
notify () {
    osascript -e "display notification \"$1\" with title \"Netinfo\""
}

# Function to find SSH Host configs with dynamic tunnels
findtunnels () {
awk '$1 == "Host" { host = $2; next; }
     $1 == "DynamicForward" { $1 = ""; sub( /^[[:space:]]*/, "" ); printf "%s;%s\n", host, $0; } ' $SSHCONF
}

# Kill process
if [ "$1" = "stop" ]; then
    notify "Stopping PID $2"
    kill "$2"
    sleep 10
    exit 0
fi

# Start SSH session
if [ "$1" = "start" ]; then
    notify "Starting session with $2"
    ssh -F "$SSHCONF" -N "$2" &
    sleep 10
    exit 0
fi


# Get defined tunnels and listening ports on localhost
TUNNELS=$(findtunnels)
LISTENERS=$(netstat -alvnp tcp | grep LISTEN)

# Set some vars to be used later
TOTAL=$(echo "$TUNNELS" | grep -c ':')
RUNNING=0
COUNTER=0

# Loop over each SSH host to find out current tunnel status
for TUNNEL in $(findtunnels|sort); do
    (( COUNTER++ ))
    SSHHOST[$COUNTER]=$(echo $TUNNEL | cut -d ";" -f 1)
    LISTENER[$COUNTER]=$(echo $TUNNEL | cut -d ";" -f 2)    
    STATUS[$COUNTER]=$(echo "$LISTENERS" | grep -c "$(echo ${LISTENER[$COUNTER]} | tr ':' '.')")
    if [[ "${STATUS[$COUNTER]}" -ne "0" ]]; then
	(( RUNNING++ ))
        PID[$COUNTER]=$(echo "$LISTENERS" | grep "$(echo ${LISTENER[$COUNTER]} | tr ':' '.')" | awk '{ print $9 }')
    else
	PID[$COUNTER]="None"
    fi 
done 

# Start printing output
echo "T [$RUNNING/$TOTAL]"
echo "---"
echo "🔄 Refresh | colo=black refresh=true"
echo "---"
for T in $(eval echo {1..$COUNTER}); do
    if [[ "${STATUS[$T]}" -ne "0" ]]; then
	COLOR="green"
        SYMBOL="🔐"
        PARAM1="stop"
	PARAM2="${PID[$T]}"
    else
	COLOR="black"
        SYMBOL=" "
	PARAM1="start"
	PARAM2="${SSHHOST[$T]}"
    fi    
    echo "${SYMBOL} ${SSHHOST[$T]} (${LISTENER[$T]}) | color=${COLOR} terminal=false refresh=true bash=$0 param1=$PARAM1 param2=$PARAM2"
done
