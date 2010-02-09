#!/bin/sh

# set some vars
RWEBROOT="/home/openttdcoop/public_html"
URLROOT="http://www.openttdcoop.org/"
USER="openttdcoop"
HOST="openttdcoop.org"
SSH="ssh $USER@$HOST"
FORCE=0

function usage {
        echo "Usage: $0 [publicserver|prozone] [-f] [-h|u] gamenr save"
        exit
}

function optcheck {
        case $1 in
                public*|Public* )
                        SERVER="PublicServer"
                        let SHIFT++;;
                pro*|Pro* )
                        SERVER="ProZone"
                        let SHIFT++;;
                -f|--force )
                        FORCE=1
                        let SHIFT++;;
        esac
}

#echo "ALL: $@"

# 2-4 parameters required
[ $# -lt 2 -o $# -gt 4 ] && usage

# check 2 first options
optcheck $1
optcheck $2
shift $SHIFT

[ $# -eq 2 ] || usage

#echo "SERVER: $SERVER / FORCE: $FORCE / NR: $1 / FILE: $2"

# check if 1st param is a number
if [ ! $1 -gt 0 ] 2>/dev/null 
then
  echo "no number!"
  usage
fi
NUMBER=$1
# check if 2nd param is a file
if [ ! -f $2 ] 
then
  echo "Couldn't find '`basename $2`'."
  usage
fi
LSAVE=$2

RFILEDIR="files/`echo $SERVER`_archive"

# check, if there is already a save with this number in the archive (if yes, it needs -f)
RSAVE="`echo $SERVER`Game_`echo $NUMBER`_Final.sav"
echo $RSAVE
EXIST=`$SSH ls $RWEBROOT/$RFILEDIR/$RSAVE 2>/dev/null | wc -l`

if [ $EXIST -gt 0 ] && [ $FORCE -eq 0 ]
then
  echo "This game ($NUMBER) is already archived. (you might use --force)"
  exit
fi

# transfer...
scp $LSAVE $USER@$HOST:$RWEBROOT/$RFILEDIR/$RSAVE
echo "Transfer done. ($LSAVE->$URLROOT/$RFILEDIR/$RSAVE)"
