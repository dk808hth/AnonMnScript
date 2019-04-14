#!/bin/bash

RED='\033[0;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

MNLISTCMD="anon-cli masternodelist full 2>/dev/null"

MNADDR=$1

if [ -z $MNADDR ]; then
    echo "usage: $0 <masternode address>"
    exit -1
fi

function _cache_command(){

    # cache life in minutes
    AGE=2

    FILE=$1
    AGE=$2
    CMD=$3

    OLD=0
    CONTENTS=""
    if [ -e $FILE ]; then
        OLD=$(find $FILE -mmin +$AGE -ls | wc -l)
        CONTENTS=$(cat $FILE);
    fi
    if [ -z "$CONTENTS" ] || [ "$OLD" -gt 0 ]; then
        echo "REBUILD"
        CONTENTS=$(eval $CMD)
        echo "$CONTENTS" > $FILE
    fi
    echo "$CONTENTS"
}



MN_LIST=$(_cache_command /tmp/cached_mnlistfull 2 "$MNLISTCMD")
SORTED_MN_LIST=$(echo "$MN_LIST" | grep -w ENABLED | sed -e 's/[}|{]//' -e 's/"//g' -e 's/,//g' | grep -v ^$ | \
awk ' \
{
    if ($7 == 0) {
        TIME = $6
        print $_ " " TIME
    }
    else {
        xxx = ("'$NOW'" - $7)
        if ( xxx >= $6) {
            TIME = $6
        }
        else {
            TIME = xxx
        }
        print $_ " " TIME
    }
}' |  sort -k10 -n)

MN_VISIBLE=$(echo "$SORTED_MN_LIST" | grep $MNADDR | wc -l)
MN_LASTPAID=$(echo "$SORTED_MN_LIST" | grep $MNADDR | awk '{print $7}')
MN_LASTPAID=$(date -d @${MN_LASTPAID})
MN_QUEUE_LENGTH=$(echo "$SORTED_MN_LIST" | wc -l)
MN_QUEUE_POSITION=$(echo "$SORTED_MN_LIST" | grep -A9999999 $MNADDR | wc -l)
MN_QUEUE_IN_SELECTION=$(( $MN_QUEUE_POSITION <= $(( $MN_QUEUE_LENGTH / 10 )) ))

echo ""
echo "${GREEN}Masternode:${NC} ${CYAN}$MNADDR${NC}"
if [ $MN_VISIBLE -gt 0 ]; then
    echo "${GREEN}Lastpaid:${NC} ${CYAN}$MN_LASTPAID${NC}"
    echo "         ${GREEN}-> queue position${NC} ${CYAN}$MN_QUEUE_POSITION/$MN_QUEUE_LENGTH${NC}"
    if [ $MN_QUEUE_IN_SELECTION -gt 0 ]; then
        echo " ${GREEN}-> SELECTION PENDING${NC}"
    fi
else
    echo "${RED}is not in masternode list"${NC}
fi
