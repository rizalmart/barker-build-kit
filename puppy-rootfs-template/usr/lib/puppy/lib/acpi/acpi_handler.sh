#!/bin/sh
# Default acpi script that takes an entry for all actions

# NOTE: This is a 2.6-centric script.  If you use 2.4.x, you'll have to
#       modify it to not use /sys

set_cpu_mode(){
	
 mode="$1"	

 CPU_CORES=$(ls /sys/devices/system/cpu | grep 'cpu[0-9].*' | tr '\n' ' ')	

 for CORE in $CPU_CORES
 do
  
  SCALEPATH="/sys/devices/system/cpu/${CORE}/cpufreq/scaling_setspeed"
  GOVPATH="/sys/devices/system/cpu/${CORE}/cpufreq/scaling_governor"
  GOVOPTS="/sys/devices/system/cpu/${CORE}/cpufreq/scaling_available_governors"
  
  if [ -f $SCALEPATH ]; then
  
    MINCORESPEED=`cat /sys/devices/system/cpu/${CORE}/cpufreq/cpuinfo_min_freq`
    MAXCORESPEED=`cat /sys/devices/system/cpu/${CORE}/cpufreq/cpuinfo_max_freq`
    
    case $mode in
     max)
       echo $MAXCORESPEED > $SCALEPATH;;
     min)
       echo $MINCORESPEED > $SCALEPATH;;
	esac
		
  fi
  
  if [ -f $GOVPATH ]; then
 
     case $mode in
       max)
        
         if [ "$(grep 'ondemand' $GOVOPTS)" != "" ]; then 
           echo "ondemand" > $GOVPATH      
         else
           echo "performance" > $GOVPATH
         fi
       
       ;;
       min)
         echo "powersave" > $GOVPATH
       ;;
	 esac
 
  fi
 
 done
	
}

set $*

PID=$(pgrep dbus-launch)
export USER=$(ps -o user --no-headers $PID)

USERHOME=$(getent passwd $USER | cut -d: -f6)
export XAUTHORITY="$USERHOME/.Xauthority"

for x in /tmp/.X11-unix/*
do
    displaynum=`echo $x | sed s#/tmp/.X11-unix/X##`
    [ x"$XAUTHORITY" != x"" ] && export DISPLAY=":$displaynum"
done

logger "ACPI event detected: $@"

case "$1" in
    button/power)
        #echo "PowerButton pressed!">/dev/tty5
        case "$2" in
            PBTN*|PWRF*)
		    logger "PowerButton pressed: $2, shutting down..."
		    env /usr/lib/puppy/lib/acpi/actions/acpi_poweroff.sh
		    ;;
            #*)      logger "ACPI action undefined: $2" ;;
        esac
        ;;
    button/sleep)
        case "$2" in
            SBTN*|SLPB*)
            
		    # suspend-to-ram
		    logger "Sleep Button pressed: $2, suspending..."
		    
		    if [ "$(pidof elogind)" != "" ]; then		    
		      loginctl suspend
		    else
		      pm-suspend
		    fi
		    
		    ;;
            #*)      logger "ACPI action undefined: $2" ;;
        esac
        ;;
    ac_adapter)
        case "$2" in
            AC*|ACAD*|ADP0*)
                case "$4" in
                    00000000)
                        logger "Enter powersave mode"
                        set_cpu_mode min
                        #/etc/laptop-mode/laptop-mode start
                    ;;
                    00000001)
                        logger "Enter perfomance mode"
                        set_cpu_mode max
                        #/etc/laptop-mode/laptop-mode stop
                    ;;
                esac
                ;;
            #*)  logger "ACPI action undefined: $2" ;;
        esac
        ;;
    battery)
        case "$2" in
            BAT0*|PNP*)
                case "$4" in
                    00000000) logger "Battery is offline"
                    ;;
                    00000001) logger "Battery is online"
                    ;;
                esac
                ;;
            #CPU0*)
            #    ;;
            #*)  logger "ACPI action undefined: $2" ;;
        esac
        ;;
    button/lid)
	case "$3" in
		close)
		
			logger "LID closed, suspending..."

		    if [ "$(pidof elogind)" != "" ]; then		    
		      loginctl suspend
		    else
			  xset dpms force off
		      pm-suspend
		    fi			
			
			;;
		open) logger "LID opened" ;;
		#*) logger "ACPI action undefined (LID): $2";;
	esac
	;;
    #video/brightnessup)      
    #  xbacklight -inc 10
	#;;
    #video/brightnessdown)  
	# xbacklight -dec 10
	#;;
    #button/volumeup)
	#  amixer -c 1 set Master playback 5%+
	#;;
    #button/volumedown)
	#  amixer -c 1 set Master playback 5%-
	#;;
    #button/mute)
	#  amixer -c 1 set Master playback toggle
	#  amixer -c 1 set Headphone playback unmute
	#;;
    #*)
    #    logger "ACPI group/action undefined: $1 / $2"
    #    ;;
esac
