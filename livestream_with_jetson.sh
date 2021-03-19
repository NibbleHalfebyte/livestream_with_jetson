#!/bin/sh
#
# File: livestream_with_jetson.sh 
# Date: 2021-03-18
# Version: 0.04n
# Developer: Marc Bayer
#
# Script for game capture live streaming to Twitch, YT, FB
# with NVidia Jetson Nano embedded computer
#
# Usage: jetson_nano2livestream_twitch.sh
#
#	MacroSilicon MS2109 USB stick - uvcvideo kernel module
#	The MS2109 HDMI2USB is limited to <=720p with 60 fps and
#	1080p with 30 fps, because the USB2 standard limits the
#	transfer rate to 30 megabytes/s!
#	For stereo sound with pulsaudio try Stary's blog:
#	https://9net.org/.../hdmi-capture-without-breaking-the-bank/
#
# List capabilties of v4l2 device, e. g. /dev/video0
# v4l2-ctl -d /dev/video0 --list-formats-ext
# List usb devices
# lsusb
# List input resolutions, e. g. usb device 001:005
# lsusb -s 001:005 -v | egrep "Width|Height"

# File variables
CONFIG_DIR=~/.config/livestream_with_jetson_conf
STREAM_KEY_FILE=live_stream_with_jetson_stream.key
INGEST_SERVER_LIST=ingest_server.lst
INGEST_SERVER_URI=ingest_server.uri
VIDEO_CONFIG_FILE=videoconfig.cfg

# Scaler type for output scaling
# 0 = nearest
# 1 = bilinear
# 2 = 5-tap
# 3 = 10-tap
# 4 = smart (default)
# 5 = nicest
SCALER_TYPE=4

CONTROL_RATE=1
# VBR or CBR
# 1 = VBR
# 2 = CBR
# 3 = VBR skip frames
# 4 = CBR skip frames
CONTROL_RATE=2

# Encoder speed & quality from bad to best
# 0 = ultra fast preset
# 1 = fast preset (default)
# 2 = medium preset
# 3 = slow preset
VIDEO_QUALITY=3

# Audioencoder kbits per second
AUDIO_BIT_RATE=160

# Sampling rate in kHz
AUDIO_SAMPLING_RATE=48000

# Number of audio channels
AUDIO_NUM_CH=2

# Multiplexer
#MUXER=mp4mux
#MUXER=qtmux
MUXER=flvmux

# Overlay size
OVL_POSITION_X=100
OVL_POSITION_Y=100
OVL_SIZE_X=640
OVL_SIZE_Y=320

# 2nd Overlay size
OVL1_POSITION_X=840
OVL1_POSITION_Y=100
OVL1_SIZE_X=640
OVL1_SIZE_Y=320

# Clean terminal
reset

# Delete last gstreamer log
rm $CONFIG_DIR/gstreamer-debug-out.log
# Check if configuration directory exists
if [ ! -e $CONFIG_DIR ]; then
	mkdir $CONFIG_DIR
	echo "\nConfig directory created in:"
	echo "\t$CONFIG_DIR\n"
elif [ $CONFIG_DIR ]; then
	echo "\nConfig directory exists:"
	echo "\t$CONFIG_DIR"
fi

# Check if a stream key file exists
if [ ! -e $CONFIG_DIR/$STREAM_KEY_FILE ]; then
	echo "\nStream key file not found in:"
	echo "\t$CONFIG_DIR/$STREAM_KEY_FILE\n"
	# Create empty stream key file
	touch $CONFIG_DIR/$STREAM_KEY_FILE
	chmod o-r $CONFIG_DIR/$STREAM_KEY_FILE
elif [ $CONFIG_DIR/$STREAM_KEY_FILE ]; then
	echo "\nStream key file found in:"
	echo "\t$CONFIG_DIR/$STREAM_KEY_FILE\n"
fi

# Check if ingest server uri file exists
if [ ! -e $CONFIG_DIR/$INGEST_SERVER_URI ]; then
	echo "\nServer URI file not found in:"
	echo "\t$CONFIG_DIR/$INGEST_SERVER_URI\n"
	# Create empty server URI file
	touch $CONFIG_DIR/$INGEST_SERVER_URI
	chmod o-r $CONFIG_DIR/$INGEST_SERVER_URI
elif [ $CONFIG_DIR/$INGEST_SERVER_URI ]; then
	echo "\nServer URI file found in:"
	echo "\t$CONFIG_DIR/$INGEST_SERVER_URI\n"
fi

# Check if stream key is empty
if [ `find $CONFIG_DIR -empty -name $STREAM_KEY_FILE` ]; then
	#/usr/bin/chromium-browser "https://www.twitch.tv/login" &
	sleep 1
	echo "================================================================================"
	echo "Please, enter your Twitch.tv stream key from your Twitch account!\n"
	echo "The key will be saved in this file:"
	echo "\t$STREAM_KEY_FILE\n"
	echo "Your will find this file in this directory:"
	echo "\t$CONFIG_DIR\n"
	echo "================================================================================"
	echo "ENTER OR COPY THE STREAM KEY INTO THIS COMMAND LINE AND PRESS RETURN:"
	read CREATE_STREAM_KEY
	echo $CREATE_STREAM_KEY > $CONFIG_DIR/$STREAM_KEY_FILE
else
	echo "FILE WITH STREAM KEY $STREAM_KEY_FILE"
	echo "\tWAS FOUND IN $CONFIG_DIR\n"
fi

while [ true ]; do
	echo "================================================================================"
	echo "Do you want to (re)enter a new stream key?"
	echo "================================================================================"
	echo "ENTER: 'YES' (in upper-case) or 'no':"
	read CHANGE_KEY
	echo
	case $CHANGE_KEY in
		YES) #/usr/bin/chromium-browser "https://www.twitch.tv/login" &
		     sleep 1
		     echo "================================================================================"
		     echo "Please, enter your Twitch.tv stream key from your Twitch account.\n"
		     echo "The key will be saved in this file:"
		     echo "\t$STREAM_KEY_FILE\n"
		     echo "Your will find the stream key file in this directory:"
		     echo "\t$CONFIG_DIR\n"
		     echo "================================================================================"
		     echo "ENTER OR COPY THE STREAM KEY INTO THIS COMMAND LINE AND PRESS RETURN:"
		     rm $CONFIG_DIR/$STREAM_KEY_FILE
		     touch $CONFIG_DIR/$STREAM_KEY_FILE
		     read NEW_STREAM_KEY
		     echo $NEW_STREAM_KEY > $CONFIG_DIR/$STREAM_KEY_FILE
		     break
		;;
		no) break
		;;
	esac
done

# Stream key for Twitch (or FB, YT, but not tested)
STREAM_KEY=$(cat $CONFIG_DIR/$STREAM_KEY_FILE)
#echo "(For debugging only!) Your stream key is: $STREAM_KEY\n"

# Twitch server for your country, see https://stream.twitch.tv/ingests/
# Search for 'ingest_server.lst', comes with the git repository
# or copy and paste the servers from https://twitchstatus.com/

# Copy ingest server list to config directory
while [ ! `find $CONFIG_DIR -name $INGEST_SERVER_LIST 2> /dev/null` ]; do
	cp `find ~ -name $INGEST_SERVER_LIST 2> /dev/null` $CONFIG_DIR 2> /dev/null
	if [ `find $CONFIG_DIR -name $INGEST_SERVER_LIST` ]; then
		echo "\n$INGEST_SERVER_LIST found in $CONFIG_DIR/"
		break
	else
		echo "\nCAN'T FIND FILE '$INGEST_SERVER_LIST' AND COPY TO:"
		echo "\t$CONFIG_DIR/\n"
		echo "\tPLEASE, COPY THE FILE '$INGEST_SERVER_LIST' INTO YOUR HOME" 
		echo "\tDIRECTORY AND RERUN livestream_with_jetson.sh !\n"
		exit
	fi
done

if [ -s $CONFIG_DIR/$INGEST_SERVER_URI ]; then
	while [ true ]; do
		echo "================================================================================"
		echo "Do you want to change the stream ingest server from your last session"
		echo "to another server?"
		echo "================================================================================"
		echo "ENTER: 'YES' (in upper-case) or 'no' and press RETURN:"
		read CHANGE_INGEST_SERVER_URI
		echo
		case $CHANGE_INGEST_SERVER_URI in
			YES) rm $CONFIG_DIR/$INGEST_SERVER_URI
			touch $CONFIG_DIR/$INGEST_SERVER_URI
			break
			;;
			no) break
			;;
		esac
	done
fi

if [ `find $CONFIG_DIR -empty -name $INGEST_SERVER_URI` ]; then
	# Print ingest server list
	INGEST_LIST_LENGTH=`awk 'END{print NR}' $CONFIG_DIR/$INGEST_SERVER_LIST`
	# echo "(For debugging only) Number of lines in $INGEST_SERVER_LIST: $INGEST_LIST_LENGTH"
	echo "================================================================================"
	for i in `seq 1 $INGEST_LIST_LENGTH` ; do
		echo | ( awk -v n=$i 'NR==n { print n").."$2, $3, $4, $5, $6, $7, $8, $1 }' $CONFIG_DIR/$INGEST_SERVER_LIST )
	done

	while [ true ]; do
		echo "================================================================================"
		echo "Choose a number from the server list for your region!"
		echo "================================================================================"
		echo "ENTER: Write the number before the server, e. g. 51, and press RETURN:"
		read SERVER_NUMBER
		# Strings for the server uri
		NET_PROTOCOL_STR="rtmp://"
		NET_SERVER_STR="/app/"
		# Set server from list
		if [ $SERVER_NUMBER -ge 1 ] && [ $SERVER_NUMBER -lt $INGEST_LIST_LENGTH ]; then
			CREATE_INGEST_SERVER_URI=${NET_PROTOCOL_STR}$(awk -v m=$SERVER_NUMBER 'NR==m { print $1 }' "${CONFIG_DIR}/${INGEST_SERVER_LIST}")${NET_SERVER_STR}
			echo $CREATE_INGEST_SERVER_URI > $CONFIG_DIR/$INGEST_SERVER_URI
			break
		fi
	done
fi

LIVE_SERVER=$(cat $CONFIG_DIR/$INGEST_SERVER_URI)
echo "Server set to: $LIVE_SERVER\n"

#echo "\nInput and output set to:\n"

# Check if a video config file exists
if [ ! -e $CONFIG_DIR/$VIDEO_CONFIG_FILE ]; then
	echo "\nVideo config file not found in:"
	echo "\t$CONFIG_DIR/$VIDEO_CONFIG_FILE\n"
	# Create empty video config key file
	touch $CONFIG_DIR/$VIDEO_CONFIG_FILE
	chmod o-r $CONFIG_DIR/$VIDEO_CONFIG_FILE
elif [ $CONFIG_DIR/$VIDEO_CONFIG_FILE ]; then
	echo "\nVideo config file found in:"
	echo "\t$CONFIG_DIR/$VIDEO_CONFIG_FILE\n"
fi

# Video capture sources
echo "================================================================================\n"
for V4L2SRC_DEVICE in /dev/video* ; do
	v4l2-ctl --device=$V4L2SRC_DEVICE --list-inputs
	echo
done
echo "================================================================================\n"
echo "Supported formats for video device $V4L2SRC_DEVICE:\n"
v4l2-ctl -d $V4L2SRC_DEVICE --list-formats-ext

# Audio capture sources
echo "================================================================================\n"
echo "List of audio devices:"
echo "\nALSA output devices:"
aplay -L
echo "\nALSA input devices:"
arecord -L
echo "Pulseaudio output devices:"
pacmd list-sinks | grep -e 'index:' -e device.string -e 'name:'
echo "Pulseaudio input devices:"
pacmd list-sources | grep -e 'index:' -e device.string -e 'name:'
echo "\n================================================================================"

# Create default video config and print results
LAST_CONFIG=1
# and parse current config file
if ( grep -q last.config $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	TMP_LAST_CONFIG=$(awk '$1 == "last.config" { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	eval "LAST_CONFIG=\${TMP_LAST_CONFIG}"
else
	# For initialization with empty videoconfig.cfg only
	echo "last.config ${LAST_CONFIG}" > $CONFIG_DIR/$VIDEO_CONFIG_FILE
fi

if ( grep -q "videodev.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	TMP_V4L2SRC_DEVICE=$(awk -v last=videodev.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	eval "V4L2SRC_DEVICE=\${TMP_V4L2SRC_DEVICE}"
else
	echo "videodev.${LAST_CONFIG} ${V4L2SRC_DEVICE}" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
fi

if ( grep -q "screenres.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	TMP_SCREEN_RESOLUTION=$(awk -v last=screenres.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	eval "SCREEN_RESOLUTION=\${TMP_SCREEN_RESOLUTION}"
else
	echo "screenres.${LAST_CONFIG} 1920x1080" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	SCREEN_RESOLUTION=1920x1080
fi

if ( grep -q "inputframerate.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	INPUT_FRAMERATE=$(awk -v last=inputframerate.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "inputframerate.${LAST_CONFIG} 30" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	INPUT_FRAMERATE=30
fi

if ( grep -q "screenaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	SCREEN_ASPECT_RATIO=$(awk -v last=screenaspect.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "screenaspect.${LAST_CONFIG} 16:9" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	SCREEN_ASPECT_RATIO=16:9
fi

if ( grep -q "pixelaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	PIXEL_ASPECT_RATIO=$(awk -v last=pixelaspect.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "pixelaspect.${LAST_CONFIG} 1:1" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	PIXEL_ASPECT_RATIO=1:1
fi

if ( grep -q "brightness.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	BRIGHTNESS=$(awk -v last=brightness.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "brightness.${LAST_CONFIG} 0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	BRIGHTNESS=0
fi

if ( grep -q "contrast.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	CONTRAST=$(awk -v last=contrast.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "contrast.${LAST_CONFIG} 0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	CONTRAST=0
fi

if ( grep -q "hue.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	HUE=$(awk -v last=hue.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "hue.${LAST_CONFIG} 0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	HUE=0
fi

if ( grep -q "saturation.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	SATURATION=$(awk -v last=saturation.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "saturation.${LAST_CONFIG} 0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	SATURATION=0
fi

if ( grep -q "crop.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	FLAG_CROP=$(awk -v last=crop.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "crop.${LAST_CONFIG} no" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	FLAG_CROP=no
fi

if ( grep -q "displayres.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	DISPLAY_RESOLUTION=$(awk -v last=displayres.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "displayres.${LAST_CONFIG} 1920x1080" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	DISPLAY_RESOLUTION=1920x1080
fi

if ( grep -q "displayaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	DISPLAY_ASPECT_RATIO=$(awk -v last=displayaspect.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "displayaspect.${LAST_CONFIG} 16:9" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	DISPLAY_ASPECT_RATIO=16:9
fi

if ( grep -q "bitrate.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	VIDEO_PEAK_BITRATE_MBPS=$(awk -v last=bitrate.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "bitrate.${LAST_CONFIG} 4.5" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	VIDEO_PEAK_BITRATE_MBPS=4.5
fi

# Ask to proceed or change the configuration
while [ true ] ; do
	# Set input settings
	SCREEN_WIDTH=$((${SCREEN_RESOLUTION%x*}))
	SCREEN_HEIGHT=$((${SCREEN_RESOLUTION#*x}))

	SCREEN_AR_X=$((${SCREEN_ASPECT_RATIO%:*}))
	SCREEN_AR_Y=$((${SCREEN_ASPECT_RATIO#*:}))

	PIXEL_AR_X=$((${PIXEL_ASPECT_RATIO%:*}))
	PIXEL_AR_Y=$((${PIXEL_ASPECT_RATIO#*:}))

	# Set output settings
	DISPLAY_WIDTH=$((${DISPLAY_RESOLUTION%x*}))
	DISPLAY_HEIGHT=$((${DISPLAY_RESOLUTION#*x}))

	DISPLAY_AR_X=$((${DISPLAY_ASPECT_RATIO%:*}))
	DISPLAY_AR_Y=$((${DISPLAY_ASPECT_RATIO#*:}))

	AUDIO_TARGET_BITRATE=$(($AUDIO_BIT_RATE*1000))

	VIDEO_PEAK_BITRATE=$( echo "scale=0; $VIDEO_PEAK_BITRATE_MBPS * 1000000 - $AUDIO_BIT_RATE * 1000" | bc -l )
	VIDEO_PEAK_BITRATE=$((${VIDEO_PEAK_BITRATE%.*}))

	VIDEO_TARGET_BITRATE=$( echo "scale=0; $VIDEO_PEAK_BITRATE * 0.8" | bc -l )
	VIDEO_TARGET_BITRATE=$((${VIDEO_TARGET_BITRATE%.*}))

	FRAMES_PER_SEC="$(($INPUT_FRAMERATE))/1"
	I_FRAME_INTERVAL=$(($INPUT_FRAMERATE*2))

	PIXEL_AR_X=$((${PIXEL_ASPECT_RATIO%:*}))
	PIXEL_AR_Y=$((${PIXEL_ASPECT_RATIO#*:}))

	PIXEL_ASPECT_RATIO="$PIXEL_AR_X:$PIXEL_AR_Y"
	PIXEL_ASPECT_RATIO_GSTREAMER="$PIXEL_AR_X/$PIXEL_AR_Y"

	FLAG_CROP=$(awk -v last=crop.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	# Crop image in absolute screen coordinates
	if [ "$FLAG_CROP" = "yes" ] ; then
		CROPPED_SCREEN_WIDTH=$( echo "scale=0; $SCREEN_WIDTH * 0.965" | bc -l )
		CROPPED_SCREEN_WIDTH=$((${CROPPED_SCREEN_WIDTH%.*}))
		CROPPED_SCREEN_HEIGHT=$( echo "scale=0; $SCREEN_HEIGHT * 0.965" | bc -l )
		CROPPED_SCREEN_HEIGHT=$((${CROPPED_SCREEN_HEIGHT%.*}))
		CROP_X0=$( echo "scale=0; ( $SCREEN_WIDTH - $CROPPED_SCREEN_WIDTH ) * 0.5" | bc -l )
		CROP_X0=$((${CROP_X0%.*}))
		CROP_Y0=$( echo "scale=0; ( $SCREEN_HEIGHT - $CROPPED_SCREEN_HEIGHT ) * 0.5" | bc -l )
		CROP_Y0=$((${CROP_Y0%.*}))
		CROP_X1=$( echo "scale=0; $CROPPED_SCREEN_WIDTH + $CROP_X0" | bc -l )
		CROP_X1=$((${CROP_X1%.*}))
		CROP_Y1=$( echo "scale=0; $CROPPED_SCREEN_HEIGHT + $CROP_Y0" | bc -l )
		CROP_Y1=$((${CROP_Y1%.*}))
	else
		CROPPED_SCREEN_WIDTH=$SCREEN_WIDTH
		CROPPED_SCREEN_HEIGHT=$SCREEN_HEIGHT
		CROP_X0=0
		CROP_Y0=0
		CROP_X1=$SCREEN_WIDTH
		CROP_Y1=$SCREEN_HEIGHT
	fi
	# Input/output settings
	echo "\nCurrent settings:"
	# Show input screen settings
	echo "\tVideo input:"
	echo "\t\tVideo input device=$V4L2SRC_DEVICE"
	echo "\t\tVideo input resolution=$SCREEN_RESOLUTION"
	echo "\t\t\tScreen width=$SCREEN_WIDTH"
	echo "\t\t\tScreen height=$SCREEN_HEIGHT\n"
	echo "\t\tVideo capture framerate=$INPUT_FRAMERATE"
	echo "\t\tVideo screen aspect ratio=$SCREEN_ASPECT_RATIO"
	echo "\t\tVideo pixel aspect ratio=$PIXEL_ASPECT_RATIO\n" 
	echo "\tPicture settings:"
	echo "\t\tBrightness=$BRIGHTNESS"
	echo "\t\tContrast=$CONTRAST"
	echo "\t\tHue=$HUE"
	echo "\t\tSaturation=$SATURATION\n"
	# Show cropping values
	echo "\tScreen cropped to:"
	echo "\t\tCropped 3.5% of the safe area down of screen the screen size."
	echo "\t\tThe image will be rescaled to display size."
	echo "\t\t\tUpper left corner coordinates"
	echo "\t\t\tX0=$CROP_X0, Y0=$CROP_Y0"
	echo "\t\t\t\tLower right corner coordinates"
	echo "\t\t\t\tX1=$CROP_X1, Y1=$CROP_Y1\n"
	echo "\t\tScreen cropped width=$CROPPED_SCREEN_WIDTH"
	echo "\t\tScreen cropped height=$CROPPED_SCREEN_HEIGHT\n"
	# Show output display settings
	echo "\tVideo output:"
	echo "\t\tVideo output resolution=$DISPLAY_RESOLUTION"
	echo "\t\t\tDisplay width=$DISPLAY_WIDTH"
	echo "\t\t\tDisplay heigth=$DISPLAY_HEIGHT\n"
	echo "\t\tVideo output framerate=$INPUT_FRAMERATE"
	echo "\t\tVideo display aspect ratio=$DISPLAY_ASPECT_RATIO"
	echo "\t\tKeyframe interval per frames=$I_FRAME_INTERVAL"
	echo "\t\tVideo H.264 peak bitrate per second=$VIDEO_PEAK_BITRATE"
	echo "\t\tVideo H.264 target bitrate bits per second=$VIDEO_TARGET_BITRATE"
	echo "\t\tAudio AAC bitrate bits per second=$AUDIO_TARGET_BITRATE\n"
	# Ask
	echo "================================================================================"
	echo "PLEASE, SCROLL UP AND CHECK THE STREAM SETTINGS BEFORE YOU PROCEED!\n"
	echo "Do your want to proceed and 'START' streaming or"
	echo "do you want to 'change' the video settings or"
	echo "do you want to 'exit'?"
	echo "================================================================================"
	echo "ENTER: The keywords 'START' for streaming, 'change' to change the video"
	echo "configuration or 'exit' to abort the script:"
	read ASK_FOR_TASK
	case $ASK_FOR_TASK in
		exit) exit
		;;
		START) break
		;;
		change) # List current configuration and ask to create new or edit current

		# Count number of individual video configs
		CONFIG_FIGURE=0
		VIDEO_CONFIG_LENGTH=`awk 'END{print NR}' $CONFIG_DIR/$VIDEO_CONFIG_FILE`
		for j in `seq 1 $VIDEO_CONFIG_LENGTH` ; do
			FIRST_STRING=$( awk -v n=$j 'NR==n { print $1 }' $CONFIG_DIR/$VIDEO_CONFIG_FILE )
			if [ "$FIRST_STRING" = "last.config" ]; then
				eval "FIRST_STRING=\${CONFIG_FIGURE}"
			fi
			TMP_CONFIG_FIGURE=${FIRST_STRING#*.}
			if [ $TMP_CONFIG_FIGURE -ge $CONFIG_FIGURE ]; then
				eval "CONFIG_FIGURE=\${TMP_CONFIG_FIGURE}"
			fi
		done
		echo "\n================================================================================"
		echo "\t$CONFIG_FIGURE video configurations found."
		echo "================================================================================"
		# List presets
		for l in `seq 1 2` ; do
		for k in `seq 1 $CONFIG_FIGURE` ; do
			if ( grep -q "videodev.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_VIDEODEV=$(awk -v last=videodev.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "screenres.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_SCREEN_RESOLUTION=$(awk -v last=screenres.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "inputframerate.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_FRAMERATE=$(awk -v last=inputframerate.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "screenaspect.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_SCREEN_ASPECT_RATIO=$(awk -v last=screenaspect.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "pixelaspect.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PIXEL_ASPECT_RATIO=$(awk -v last=pixelaspect.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "displayres.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_DISPLAY_RESOLUTION=$(awk -v last=displayres.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "displayaspect.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_DISPLAY_ASPECT_RATIO=$(awk -v last=displayaspect.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "bitrate.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_VIDEO_PEAK_BITRATE=$(awk -v last=bitrate.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "crop.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_FLAG_CROP=$(awk -v last=crop.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "brightness.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_BRIGHTNESS=$(awk -v last=brightness.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "contrast.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_CONTRAST=$(awk -v last=contrast.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "hue.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_HUE=$(awk -v last=hue.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "saturation.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_SATURATION=$(awk -v last=saturation.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			echo "$k) $PRINT_VIDEODEV $PRINT_SCREEN_RESOLUTION@$PRINT_FRAMERATE ($PRINT_SCREEN_ASPECT_RATIO) -> $PRINT_DISPLAY_RESOLUTION@$PRINT_FRAMERATE ($PRINT_DISPLAY_ASPECT_RATIO) > $PRINT_VIDEO_PEAK_BITRATE mbps"
			echo "\tcrop input size=$PRINT_FLAG_CROP, brightness=$PRINT_BRIGHTNESS, contrast=$PRINT_CONTRAST, hue=$PRINT_HUE, saturation=$PRINT_SATURATION\n"
		done
		if [ $l = 2 ]; then
			break
		fi
		NEW_PRESET=$( echo "scale=0; $CONFIG_FIGURE + 1" | bc -l )
		echo "$NEW_PRESET) NEW (Create a new preset)"
		echo "================================================================================"
		echo "Your current configuration is set to no. $LAST_CONFIG"
		echo "================================================================================"
		echo "Enter the number of the preset you want to switch to:"
		read CHOOSE_FIGURE
		if [ $CHOOSE_FIGURE -ge 1 ] && [ $CHOOSE_FIGURE -le $CONFIG_FIGURE ]; then
			eval "LAST_CONFIG=\${CHOOSE_FIGURE}"
			sed -i "/last.config/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "last.config $CHOOSE_FIGURE" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
			if ( grep -q "videodev.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				V4L2SRC_DEVICE=$(awk -v last=videodev.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "screenres.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				SCREEN_RESOLUTION=$(awk -v last=screenres.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "inputframerate.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				INPUT_FRAMERATE=$(awk -v last=inputframerate.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "screenaspect.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				SCREEN_ASPECT_RATIO=$(awk -v last=screenaspect.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "pixelaspect.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PIXEL_ASPECT_RATIO=$(awk -v last=pixelaspect.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "displayres.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				DISPLAY_RESOLUTION=$(awk -v last=displayres.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "displayaspect.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				DISPLAY_ASPECT_RATIO=$(awk -v last=displayaspect.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "bitrate.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				VIDEO_PEAK_BITRATE_MBPS=$(awk -v last=bitrate.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "crop.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				FLAG_CROP=$(awk -v last=crop.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "brightness.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				BRIGHTNESS=$(awk -v last=brightness.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "contrast.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				CONTRAST=$(awk -v last=contrast.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "hue.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				HUE=$(awk -v last=hue.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "saturation.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				SATURATION=$(awk -v last=saturation.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
		elif [ "$CHOOSE_FIGURE" = "$NEW_PRESET" ] ; then
			eval "LAST_CONFIG=\${NEW_PRESET}"
			sed -i "/last.config/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "last.config $CHOOSE_FIGURE" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

	# Create new preset
	# Set video device
	while [ true ] ; do
		echo "================================================================================"
		echo "List of capture devices:"
		for V4L2SRC_DEVICE in /dev/video* ; do
			echo "\t$V4L2SRC_DEVICE\n"
			v4l2-ctl --device=$V4L2SRC_DEVICE --list-inputs
			echo
		done
		echo "Do you want to use this video device for main video in or another device?"
		echo "To set another device enter the path, e. g. '/dev/video1' and enter.\n"
		echo "================================================================================"
		echo "\tCurrent MAIN VIDEO (INPUT) set to: $V4L2SRC_DEVICE"
		echo "================================================================================"
		echo "ENTER: 'yes' or the path to another device:"
		read OTHER_V4L2SRC_DEVICE
		if [ "${OTHER_V4L2SRC_DEVICE}" = "yes" ]; then
			echo "Set Video for Linux 2 input device to: $V4L2SRC_DEVICE\n"
			break
		else
			eval "V4L2SRC_DEVICE=\${OTHER_V4L2SRC_DEVICE}"
			sed -i "/videodev.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "videodev.${LAST_CONFIG} $V4L2SRC_DEVICE" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "Set Video for Linux 2 input device to: $V4L2SRC_DEVICE\n"
			break
		fi
	done
	# End of setting video device
	# Set input resolution
	while [ true ] ; do
		echo "================================================================================"
		echo "Input resolutions:\n"
		echo " 1) 1920x1080@30 - Full HD, aspect 16:9, with 30 frames per second"
		echo " 2) 1360x768@60 - HD Ready, aspect 16:9, with 60 frames per second"
		echo " 3) 1360x768@30 - HD Ready, aspect 16:9, with 60 frames per second"
		echo " 4) 1280x720@60 - HD Ready, aspect 16:9, with 60 frames per second"
		echo " 5) 1280x720@30 - HD Ready, aspect 16:9, with 30 frames per second"
		echo " 6) 720x576@60 - PAL50/60, aspect 4:3 to 16:9 wide, with 60 frames per second"
		echo " 7) 720x576@30 - PAL50/60, aspect 4:3 to 16:9 wide, with 30 frames per second"
		echo " 8) 720x480@60 - NTSC, aspect 4:3 to 16:9 wide, with 60 frames per second"
		echo " 9) 720x480@30 - NTSC, aspect 4:3 to 16:9 wide, with 30 frames per second"
		echo "10) 640x480@60 - SDTV, aspect 4:3 to 16:9 wide, with 60 frames per second"
		echo "11) 640x480@30 - SDTV, aspect 4:3 to 16:9 wide, with 30 frames per second"
		echo "================================================================================"
		echo "Choose an input resolution from the table. Type the number and press ENTER:"
		read RESOLUTION_TABLE_IN
		if [ $RESOLUTION_TABLE_IN -ge 1 ] && [ $RESOLUTION_TABLE_IN -le 11 ]; then
			case $RESOLUTION_TABLE_IN in
				1) TMP_SCREEN_RESOLUTION_=1920x1080
				TMP_INPUT_FRAMERATE_=30
				TMP_SCREEN_ASPECT_RATIO_=16:9
				;;
				2) TMP_SCREEN_RESOLUTION_=1360x768
				TMP_INPUT_FRAMERATE_=60
				TMP_SCREEN_ASPECT_RATIO_=16:9
				;;
				3) TMP_SCREEN_RESOLUTION_=1360x768
				TMP_INPUT_FRAMERATE_=30
				TMP_SCREEN_ASPECT_RATIO_=16:9
				;;
				4) TMP_SCREEN_RESOLUTION_=1280x720
				TMP_INPUT_FRAMERATE_=60
				TMP_SCREEN_ASPECT_RATIO_=16:9
				;;
				5) TMP_SCREEN_RESOLUTION_=1280x720
				TMP_INPUT_FRAMERATE_=30
				TMP_SCREEN_ASPECT_RATIO_=16:9
				;;
				6) TMP_SCREEN_RESOLUTION_=720x576
				TMP_INPUT_FRAMERATE_=60
				TMP_SCREEN_ASPECT_RATIO_=4:3
				;;
				7) TMP_SCREEN_RESOLUTION_=720x576
				TMP_INPUT_FRAMERATE_=30
				TMP_SCREEN_ASPECT_RATIO_=4:3
				;;
				8) TMP_SCREEN_RESOLUTION_=720x480
				TMP_INPUT_FRAMERATE_=60
				TMP_SCREEN_ASPECT_RATIO_=4:3
				;;
				9) TMP_SCREEN_RESOLUTION_=720x480
				TMP_INPUT_FRAMERATE_=30
				TMP_SCREEN_ASPECT_RATIO_=4:3
				;;
				10) TMP_SCREEN_RESOLUTION_=640x480
				TMP_INPUT_FRAMERATE_=60
				TMP_SCREEN_ASPECT_RATIO_=4:3
				;;
				11) TMP_SCREEN_RESOLUTION_=640x480
				TMP_INPUT_FRAMERATE_=30
				TMP_SCREEN_ASPECT_RATIO_=4:3
				;;
			esac
			echo "================================================================================"
			echo "Screen resolution (input) set to: $SCREEN_RESOLUTION@$INPUT_FRAMERATE"
			echo "================================================================================"

			eval "SCREEN_RESOLUTION=\${TMP_SCREEN_RESOLUTION_}"
			sed -i "/screenres.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "screenres.${LAST_CONFIG} $SCREEN_RESOLUTION" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

			eval "SCREEN_ASPECT_RATIO=\${TMP_SCREEN_ASPECT_RATIO_}"
			sed -i "/screenaspect.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "screenaspect.${LAST_CONFIG} $SCREEN_ASPECT_RATIO" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
			break
		fi
	done
	# End of setting input resolution
	# Ask for cropping
	while [ true ] ; do
		echo "================================================================================"
		echo "Do you want to crop the border of the picture of the video input?"
		echo "The picture will be cropped about 3.5% of its border, e. g. for PAL/NTSC"
		echo "analog signals from an analog to hdmi converter."
		echo "Write 'yes'to cop image and 'no' for source, as it is, e. g. HD input signal."
		echo "================================================================================"
		echo "Crop input frames? Type 'yes' or 'no'?"
		read ASK_FOR_CROP
		case $ASK_FOR_CROP in
			yes) TMP_FLAG_CROP_="yes"
				eval "FLAG_CROP=\${TMP_FLAG_CROP_}"
				sed -i "/crop.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				echo "crop.${LAST_CONFIG} $TMP_FLAG_CROP_" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
				break
			;;
			no) TMP_FLAG_CROP_="no"
				eval "FLAG_CROP=\${TMP_FLAG_CROP_}"
				sed -i "/crop.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				echo "crop.${LAST_CONFIG} $TMP_FLAG_CROP_" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
				break
			;;
		esac
	done
	# End of cropping dialog
	# Set output resolution
	while [ true ] ; do
		echo "================================================================================"
		echo "Output resolutions:\n"
		echo " 1) 1920x1080@30 - Full HD, aspect 16:9, with 30 frames per second"
		echo " 2) 1280x720@60 - HD Ready, aspect 16:9, with 60 frames per second"
		echo " 3) 1280x720@30 - HD Ready, aspect 16:9, with 30 frames per second"
		echo "================================================================================"
		echo "Choose an output resolution from the table. Type the number and press ENTER:"
		read RESOLUTION_TABLE_OUT
		if [ $RESOLUTION_TABLE_OUT -ge 1 ] && [ $RESOLUTION_TABLE_OUT -le 3 ]; then
			case $RESOLUTION_TABLE_OUT in
				1) TMP_DISPLAY_RESOLUTION_=1920x1080
				TMP_DISPLAY_ASPECT_RATIO_=16:9
				TMP_OUTPUT_FRAMERATE_=30
				;;
				2) TMP_DISPLAY_RESOLUTION_=1280x720
				TMP_DISPLAY_ASPECT_RATIO_=16:9
				TMP_OUTPUT_FRAMERATE_=60
				;;
				3) TMP_DISPLAY_RESOLUTION_=1280x720
				TMP_DISPLAY_ASPECT_RATIO_=16:9
				TMP_OUTPUT_FRAMERATE_=30
				;;
			esac

			SCREEN_AR_X=${SCREEN_ASPECT_RATIO%:*}
			SCREEN_AR_Y=${SCREEN_ASPECT_RATIO#*:}

			DISPLAY_AR_X=${DISPLAY_ASPECT_RATIO%:*}
			DISPLAY_AR_Y=${DISPLAY_ASPECT_RATIO#*:}

			PIXEL_AR_X=$( echo "scale=0; $DISPLAY_AR_X / $SCREEN_AR_X" | bc -l )
			PIXEL_AR_X=${PIXEL_AR_X%.*}
			PIXEL_AR_Y=$( echo "scale=0; $DISPLAY_AR_Y / $SCREEN_AR_Y" | bc -l )
			PIXEL_AR_Y=${PIXEL_AR_Y%.*}

			TMP_PIXEL_ASPECT_RATIO="$PIXEL_AR_X:$PIXEL_AR_Y"
			PIXEL_ASPECT_RATIO="$PIXEL_AR_X:$PIXEL_AR_Y"
			PIXEL_ASPECT_RATIO_GSTREAMER="$PIXEL_AR_X/$PIXEL_AR_Y"

			eval "DISPLAY_RESOLUTION=\${TMP_DISPLAY_RESOLUTION_}"
			sed -i "/displayres.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "displayres.${LAST_CONFIG} $DISPLAY_RESOLUTION" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

			eval "DISPLAY_ASPECT_RATIO=\${TMP_DISPLAY_ASPECT_RATIO_}"
			sed -i "/displayaspect.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "displayaspect.${LAST_CONFIG} $DISPLAY_ASPECT_RATIO" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
			# Set bitrate after evalutation
			if [ "$DISPLAY_RESOLUTION" = "1920x1080" ] && [ "$TMP_OUTPUT_FRAMERATE_" = "30" ]; then
				TMP_VIDEO_PEAK_BITRATE_MBPS_=4.5
			elif [ "$DISPLAY_RESOLUTION" = "1280x720" ] && [ "$TMP_OUTPUT_FRAMERATE_" = "60" ]; then
				TMP_VIDEO_PEAK_BITRATE_MBPS_=4.5
			elif [ "$DISPLAY_RESOLUTION" = "1280x720" ] && [ "$TMP_OUTPUT_FRAMERATE_" = "30" ]; then
				TMP_VIDEO_PEAK_BITRATE_MBPS_=3.5
			else
				echo "ERROR: Couldn't write bitrate and framerate into config file!"
				exit
			fi
			#
			eval "INPUT_FRAMERATE=\${TMP_OUTPUT_FRAMERATE_}"
			sed -i "/inputframerate.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "inputframerate.${LAST_CONFIG} $INPUT_FRAMERATE" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

			eval "VIDEO_PEAK_BITRATE_MBPS=\${TMP_VIDEO_PEAK_BITRATE_MBPS_}"
			sed -i "/bitrate.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "bitrate.${LAST_CONFIG} $VIDEO_PEAK_BITRATE_MBPS" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

			eval "TMP_PIXEL_ASPECT_RATIO_=\${TMP_PIXEL_ASPECT_RATIO}"
			sed -i "/pixelaspect.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "pixelaspect.${LAST_CONFIG} $TMP_PIXEL_ASPECT_RATIO_" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

			echo "================================================================================"
			echo "Display resolution (input) set to: $DISPLAY_RESOLUTION@$INPUT_FRAMERATE"
			echo "================================================================================"

			break
		fi
	done
	# End of setting output resolution
	# End of create new preset

		fi
		done
		echo "================================================================================"
		echo "Switched to configuration no. $LAST_CONFIG"
		echo "================================================================================"
		;;
	esac
done

# For testing purpose switch the av pipeline output to filesink. It's very important to verify the
# output frame rate of the stream. Test the frame rate with of the video.mp4 file with mplayer!

# gst-launch-1.0 $1 $MUXER streamable=true name=mux \
# ! tee name=container0 \
# ! queue \
# ! rtmpsink location="${LIVE_SERVER}${STREAM_KEY}?bandwidth_test=false" sync=false async=false \
gst-launch-1.0 $1 $MUXER name=mux \
! queue \
! filesink location="/media/marc/data/video/gamecapture/test/video.mp4"  sync=false async=false \
\
v4l2src \
	brightness=$BRIGHTNESS \
	contrast=$CONTRAST \
	device=$V4L2SRC_DEVICE \
	hue=$HUE \
	io-mode=2 \
	pixel-aspect-ratio=$PIXEL_ASPECT_RATIO_GSTREAMER \
	saturation=$SATURATION \
! "image/jpeg,width=${SCREEN_WIDTH},height=${SCREEN_HEIGHT},framerate=${FRAMES_PER_SEC}" \
! jpegparse \
! nvjpegdec \
! "video/x-raw" \
! nvvidconv \
! "video/x-raw(memory:NVMM)" \
! nvvidconv left=$CROP_X0 right=$CROP_X1 top=$CROP_Y0 bottom=$CROP_Y1 \
! nvvidconv interpolation-method=$SCALER_TYPE \
! "video/x-raw(memory:NVMM),width=${DISPLAY_WIDTH},height=${DISPLAY_HEIGHT},format=NV12" \
! tee name=videosrc0 \
! queue \
! omxh264enc iframeinterval=$I_FRAME_INTERVAL \
	bitrate=$VIDEO_TARGET_BITRATE \
	peak-bitrate=$VIDEO_PEAK_BITRATE \
	control-rate=$CONTROL_RATE \
	preset-level=$VIDEO_QUALITY \
! "video/x-h264,stream-format=byte-stream" \
! h264parse \
! mux. \
\
alsasrc \
! tee name=audiosrc0 \
! queue \
! "audio/x-raw,format=S16LE,layout=interleaved, rate=${AUDIO_SAMPLING_RATE}, channels=${AUDIO_NUM_CH}" \
! voaacenc bitrate=$AUDIO_BIT_RATE \
! aacparse \
! mux. \
\
videosrc0. \
! queue \
! nvoverlaysink \
	overlay-x=$OVL_POSITION_X \
	overlay-y=$OVL_POSITION_Y \
	overlay-w=$OVL_SIZE_X \
	overlay-h=$OVL_SIZE_Y \
	overlay=1 \
	overlay-depth=1 \
	sync=false \
	async=false \
\
audiosrc0. \
! queue \
! audioconvert \
! audioresample \
! pulsesink mute=true \
	sync=false \
	async=false \
> $CONFIG_DIR/gstreamer-debug-out.log &
# \
# container0. \
# ! queue \
# ! filesink location="/media/marc/data/video/gamecapture/test/video.mp4" \
# > $CONFIG_DIR/gstreamer-debug-out.log &

# Get the PID of the gestreamer pipeline
PID_GSTREAMER_PIPELINE=$!

sleep 2
echo "\nWriting GStreamer debug log into:"
echo "\t$CONFIG_DIR/gstreamer-debug-out.log"

# Pipline and stream started
if [ `pidof gst-launch-1.0` = $PID_GSTREAMER_PIPELINE ]; then
	echo "\n\tYOU'RE STREAM IS NOW ONLINE & LIVE!\n"
fi

# Read key press for stopping gestreamer pipeline
while [ true ] ; do
	echo "================================================================================"
	echo "\tWrite the word 'quit' and enter to stop the stream!"
	echo "================================================================================"
	echo "\tENTER: 'quit' and RETURN:\n"
	read QUIT_STREAM
	if [ "${QUIT_STREAM}" = "quit" ]; then
		echo "================================================================================"
		echo "\tARE YOU REALLY SURE? PLEASE ENTER THE WORD 'quit' AGAIN AND RETURN:"
		echo "================================================================================"
		read REALLY_QUIT_STREAM
			if [ "${REALLY_QUIT_STREAM}" = "quit" ]; then
				break
			fi
	fi
done
kill -s 15 $PID_GSTREAMER_PIPELINE
echo "\n================================================================================\n"
echo "\t\tSTREAM STOPPED!\n"
echo "================================================================================"
#
