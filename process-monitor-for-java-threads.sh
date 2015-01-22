#!/bin/bash

# This script will by default run for one hour and check every minute !
# The overhead of the system resources is around 0.05 seconds per run (when not creating a thread dump)
# do not run this script in a frequence less than a minute
# a threaddump takes around 100K disk space

VERSION=2015-01-22-RBR

CHECKINTERVAL=1
LOOPDURATION=60
THREADDUMPDIR=$(pwd)
# /!\ A thread dump will take up 100k of disk resources
THREADDUMPMAXBACKUP=100

ULIMIT_U=1024
ULIMT_U_TDUMP_START=1

function usage()
{
	echo "$0, $VERSION"
	echo "Usage: "
	echo "    nohup $0 -procuniqueid <your-proc-id> [-checkinterval <checkminutes>] [-loopduration <loopminutes>] [-theaddumpdir <dir>] [-threaddumpmaxbackup <#>] [-ulimitmaxproc <1024>] [-ulimitmaxprocThreadDumpStart <#>] &"
	echo "    Do not run with ROOT user !"
	echo "    -procuniqueid . The string that is contained in your process, used to grep the ps command. No quotes allowed"
	echo "    -checkinterval in minutes. Default = $CHECKINTERVAL. Process will be checked every x minutes."
	echo "    -loopduration in minutes. Default = $LOOPDURATION. Help : 60 = 1 hour, 1440 = 1 day ,10080 = 1 week, 43829 ~ 1 month"
  echo "    -threaddumpdir . Default = $THREADDUMPDIR. All logs and threaddumps will be placed here."
	echo "    -threaddumpmaxbackup the maximum threaddumps created. Default = $THREADDUMPMAXBACKUP. Avoid disk full issue."
  echo "    -ulimitmaxproc . Default = $ULIMIT_U"
  echo "    -ulimitmaxprocThreadDumpStart . Limit where script starts to create thread dumps. Default = $ULIMT_U_TDUMP_START"
	echo "Behavior:"
	echo "    This script will run for <loopminutes> minutes and will monitor the number of processes created by the process"
	echo "    The procuniqueid does not have to exist at the moment of exection"
	
	echo "Output: "
	echo "    <dir>/$0.log"
  echo "    <dir>/threaddump-xxx"
	echo "Example: "
	echo "    nohup $0 -procuniqueid 'app.name=rhq-server' -checkinterval 1 -loopduration 10080 &"
	echo "    nohup $0 -procuniqueid 'app.name=rhq-server' -checkinterval 1 -loopduration 60 -theaddumpdir /tmp/jon-process-monitor -threaddumpmaxbackup 50 -ulimitmaxproc 1024 -ulimitmaxprocThreadDumpStart 90 &"
}

# first param : the option (string)
# second param : the integer to be checked
function hastobeanumber()
{
	re='^[0-9]+$'
	if ! [[ $2 =~ $re ]] ; then
		echo "$1 expects an integer: $2 is not."
		exit 1
	fi
}

if [ "$1" == "-?" -o "$1" == "-h" ]; then
  usage
  exit 1
fi

if [ "$(id -un)" = "root" ]; then
  echo "Should not be run as 'root', but with the user running the JVM !"
  exit 1
fi

if [ "x$JAVA_HOME" != "x" ]; then
		JSTACK="$JAVA_HOME/bin/jstack"
else
		JSTACK="jstack"
fi

if [ "x$(command -v $JSTACK)" = "x" ]; then
  echo "$JSTACK is not available on system or JAVA_HOME is not set !"
  exit 1
fi

SCRIPTNAME=$0
ACTION=
PS_COMMAND=
JSTACK_COMMAND=

if [ "x$1" = "x" ]; then
  usage
  exit 1
fi


while [ "x$1" != "x" ]; do
  case "$1" in
  -procuniqueid)
    if [ "x$2" = "x" ]; then
      usage
      exit 1
    fi
    ACTION=RUN
    PS_COMMAND="ps -C java -L -o pid,tid,pcpu,state,nlwp,args \| grep '$2'"
    PROCUNIQUEID=$2
    shift
    shift
    ;;
  -checkinterval)
    # TODO CHECKINTERVAL or $2 should not be null
    hastobeanumber $1 $2
		CHECKINTERVAL=$2
    shift
    shift
    ;;
  -loopduration)
    hastobeanumber $1 $2
    LOOPDURATION=$2
    shift
    shift
    ;;
  -threaddumpdir)
    THREADDUMPDIR=$2
    shift
    shift
    ;;
  -threaddumpmaxbackup)
    hastobeanumber $1 $2
    THREADDUMPMAXBACKUP=$2
    shift
    shift
    ;;
  -ulimitmaxproc)
    hastobeanumber $1 $2
    ULIMIT_U=$2
    shift
    shift
    ;;
  -ulimitmaxprocThreadDumpStart)
    hastobeanumber $1 $2
    ULIMT_U_TDUMP_START=$2
    shift
    shift
    ;;
  *)
    echo "Invalid option: $2"
    usage
    exit 1
    ;;
  esac
done

# procuniqueid was not passed as parameter
if [ "x$ACTION" = "x" ]; then
  usage
  exit 1
fi

# calculates the loop iterations
# TODO check if it an integer
LOOPITERATION=$((LOOPDURATION/CHECKINTERVAL))

# calculates the limit of used processes from where
# the script will start logging and thread dumping
#LOWERDUMPLIMIT=$((ULIMIT_U/ULIMT_U_TDUMP_START*100))

THREADDUMPS_ALREADYDUMPED=0

echo "timestamp,'string',# pids,pid,# threads"  >> ${THREADDUMPDIR}/${SCRIPTNAME}.log

if [ "$ACTION" == "RUN" ]; then

	for ((i=1; i <= $LOOPITERATION; i++))
	do
	  TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
   	# retrive single PID of Java service using passed in string
 		singlePID=$(ps -C java -L -o pid,tid,pcpu,state,nlwp,args | grep $PROCUNIQUEID | awk '{ print $1 }' | uniq | wc -l)

    # if not exactly one singlePID is found, do nothing
 		if [ "1" != "$singlePID" ]; then
			echo "$TIMESTAMP,'$PROCUNIQUEID',$singlePID,ERROR,ERROR" >> ${THREADDUMPDIR}/${SCRIPTNAME}.log
		else
			# retrive the actual PID
			PID=$(ps -C java -L -o pid,tid,pcpu,state,nlwp,args | grep $PROCUNIQUEID | awk '{ print $1 }' | uniq)
			# get the number of threads linked to the PID
   		singlePIDthreadCount=$(ps -C java -L -o pid,tid,pcpu,state,nlwp,args | grep $PROCUNIQUEID | awk '{ print $1 }' | wc -l)
			echo "$TIMESTAMP,'$PROCUNIQUEID',1,$PID,$singlePIDthreadCount"  >> ${THREADDUMPDIR}/${SCRIPTNAME}.log

   		# if threads increase drastically, we start thread dumping
			if [ $ULIMT_U_TDUMP_START -lt $singlePIDthreadCount ] && [ $THREADDUMPS_ALREADYDUMPED -lt $THREADDUMPMAXBACKUP ]; then
        # jstack -l  long listing. Prints additional information about locks
				$JSTACK -l $PID > theaddump$THREADDUMPS_ALREADYDUMPED-$TIMESTAMP.log
				let THREADDUMPS_ALREADYDUMPED=THREADDUMPS_ALREADYDUMPED+1
			fi
		fi
		# sleeping x minutes
		sleep ${CHECKINTERVAL}m
	done
fi