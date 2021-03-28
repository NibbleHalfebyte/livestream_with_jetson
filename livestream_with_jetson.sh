#!/bin/sh
#
# File: livestream_with_jetson.sh 
# Date: 2021-03-28
# Version: 0.16
# Developer: Marc Bayer
# Email: marc.f.bayer@gmail.com
#
# Script for game capture live streaming to Twitch, YT, FB
# with NVidia Jetson Nano embedded computer
# #blub
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

# Date and time string
DATE_TIME=`date +%F-%Hh%Mm%Ss`

# File variables
CONFIG_DIR=$HOME/.config/livestream_with_jetson_conf
STREAM_KEY_FILE=live_stream_with_jetson_stream.key
INGEST_SERVER_LIST=ingest_server.lst
INGEST_SERVER_URI=ingest_server.uri
VIDEO_CONFIG_FILE=videoconfig.cfg
# %04d = 0000, 0001...
# %03d = 000, 001, 002,...
BG_FILE=bg_black.%04d.jpg

VIDEO_FILE="video-${DATE_TIME}.mp4"

# Video peak bitrate to standard bitrate ratio
RATIO_BITRATE=0.9 # default = 0.8

# queue default 200 bytes
QUEUE_SIZE=200

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

# H.264 encoder profile
# 1 = baseline profile (video conference)
# 2 = main profile (broadcast)
# 8 = high profile (High Definition broadcast)
H264_PROFILE=8

# Set cabac-entropy-coding for H.264
CABAC=true

# Audioencoder kbits per second
#AUDIO_BIT_RATE=160
AUDIO_BIT_RATE=128

# Sampling rate in kHz (default for video 48kHz)
# But flvmux can't handle 48kHz correctly
AUDIO_SAMPLING_RATE=44100
#AUDIO_SAMPLING_RATE=48000

# Number of audio channels
AUDIO_NUM_CH=2

# Overlay size
OVL1_POSITION_X=0
OVL1_POSITION_Y=64
OVL1_SIZE_X=640
OVL1_SIZE_Y=320

# 2nd Overlay size
OVL2_POSITION_X=640
OVL2_POSITION_Y=64
OVL2_SIZE_X=640
OVL2_SIZE_Y=320

# 3rd Overlay size
OVL3_POSITION_X=1280
OVL3_POSITION_Y=64
OVL3_SIZE_X=640
OVL3_SIZE_Y=320

# Background with border
VIEW_POS_X=0
VIEW_POS_Y=0

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

# Copy default background config directory
while [ ! `find $CONFIG_DIR -name bg_black.0000.jpg 2> /dev/null` ]; do
	cp `find $HOME -name bg_black.0000.jpg 2> /dev/null` $CONFIG_DIR 2> /dev/null
	if [ `find $CONFIG_DIR -name bg_black.0000.jpg` ]; then
		echo "'bg_black.0000.jpg' found in $CONFIG_DIR/\n"
		break
	else
		echo "\nCAN'T FIND FILE 'bg_black.0000.jpg' AND COPY TO:"
		echo "\t$CONFIG_DIR/\n"
		echo "\tPLEASE, COPY THE FILE 'bg_black.0000.jpg' INTO YOUR HOME" 
		echo "\tDIRECTORY AND RERUN livestream_with_jetson.sh !\n"
		exit
	fi
done

# Twitch server for your country, see https://stream.twitch.tv/ingests/
# Search for 'ingest_server.lst', comes with the git repository
# or copy and paste the servers from https://twitchstatus.com/

# Copy ingest server list to config directory
while [ ! `find $CONFIG_DIR -name $INGEST_SERVER_LIST 2> /dev/null` ]; do
	cp `find $HOME -name $INGEST_SERVER_LIST 2> /dev/null` $CONFIG_DIR 2> /dev/null
	if [ `find $CONFIG_DIR -name $INGEST_SERVER_LIST` ]; then
		echo "$INGEST_SERVER_LIST found in $CONFIG_DIR/\n"
		break
	else
		echo "\nCAN'T FIND FILE '$INGEST_SERVER_LIST' AND COPY TO:"
		echo "\t$CONFIG_DIR/\n"
		echo "\tPLEASE, COPY THE FILE '$INGEST_SERVER_LIST' INTO YOUR HOME" 
		echo "\tDIRECTORY AND RERUN livestream_with_jetson.sh !\n"
		exit
	fi
done

# Check if stream key is empty
if [ `find $CONFIG_DIR -empty -name $STREAM_KEY_FILE` ]; then
	# /usr/bin/chromium-browser "https://www.twitch.tv/login" 2>&1 &
	# PID_OF_BROWSER=$!
	sleep 1

	echo "================================================================================"
	echo "\tYOU NEED A NVIDIA JETSON NANO FOR THIS SHELL SCRIPT!!!"
	echo "\tElse you will need an USB2.0/USB3.x HDMI Framegrabber,"
	echo "\tthese cheap Macro Silicon 2109 will, others may work,"
	echo "\tand a usb soundcard, e. g. Behringer UCA202 will do it."
	echo "\tAs USB webcam any brand with an MJPEG output of 1280x720p"
	echo "\t with 30 frames per second should work, e. g. the"
	echo "\t Logitech C270 USB webcam or better."
	echo "IMPORTANT: Switch the NVIDIA Jetson Nano to full clock"
	echo "\t speed with the command 'sudo jetson_clocks'!"
	echo "\t Or, modify rc.local for setting the clocks to full"
	echo "\t compute power after every restart!"
	echo "================================================================================"
	echo "\t\t'https://www.twitch.tv/login'"
	echo "================================================================================"
	echo "Please, enter your Twitch.tv stream key from your Twitch account!"
	echo "Log the browser into your account and search the key in your account settings.\n"
	echo "The key will be saved in this file:"
	echo "\t$STREAM_KEY_FILE\n"
	echo "Your will find this file in this directory:"
	echo "\t$CONFIG_DIR\n"
	echo "The browser will be closed after entering the key."
	echo "================================================================================"
	echo "ENTER OR COPY THE STREAM KEY INTO THIS COMMAND LINE AND PRESS RETURN:"
	read CREATE_STREAM_KEY
	echo $CREATE_STREAM_KEY > $CONFIG_DIR/$STREAM_KEY_FILE
	# kill -s 15 $PID_OF_BROWSER
else
	echo "FILE WITH STREAM KEY $STREAM_KEY_FILE"
	echo "\tWAS FOUND IN $CONFIG_DIR\n"
fi

while [ true ]; do
	echo "================================================================================"
	echo "Do you want to (re)enter a new stream key?"
	echo "================================================================================"
	echo "ENTER: 'YES' (in upper-cases) or 'no':"
	read CHANGE_KEY
	echo
	case $CHANGE_KEY in
		YES) #/usr/bin/chromium-browser "https://www.twitch.tv/login" &
		     sleep 1
		     echo "================================================================================"
		     echo "\t\t'https://www.twitch.tv/login'"
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

if [ -s $CONFIG_DIR/$INGEST_SERVER_URI ]; then
	while [ true ]; do
		echo "================================================================================"
		echo "Do you want to change the stream ingest server from your last session"
		echo "to another server?"
		echo "================================================================================"
		echo "ENTER: 'YES' (in upper-cases) or 'no' and press RETURN:"
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

# Set default video devices, e. g. Macro Silicon 2109 & Logitech C270
V4L2SRC_DEVICE=`v4l2-ctl --list-devices | awk '/Video/ { getline; print $1}'`
V4L2SRC_CAMERA=`v4l2-ctl --list-devices | awk '/Camera/ { getline; print $1}'`
echo "Found Video: $V4L2SRC_DEVICE\n"
echo "Found Camera: $V4L2SRC_CAMERA"

if [ -z ${V4L2SRC_DEVICE+x} ]; then
	V4L2SRC_DEVICE="/dev/video0"
fi
if [ -z ${V4L2SRC_CAMERA+x} ]; then
	V4L2SRC_CAMERA="/dev/video1"
fi

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
	echo "videodev.${LAST_CONFIG} /dev/video0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
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

if ( grep -q "record.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	RECORD_VIDEO=$(awk -v last=record.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "record.${LAST_CONFIG} no" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	RECORD_VIDEO="no"
fi

if ( grep -q "filepath.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	FILE_PATH=$(awk -v last=filepath.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "filepath.${LAST_CONFIG} /dev/null" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	eval "FILE_PATH=/dev/null"
fi

if ( grep -q "background.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	BACKGROUND=$(awk -v last=background.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "background.${LAST_CONFIG} no" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	BACKGROUND="no"
fi

if ( grep -q "bgpath.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	BG_PATH=$(awk -v last=bgpath.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "bgpath.${LAST_CONFIG} $CONFIG_DIR" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	eval "BG_PATH=$CONFIG_DIR"
fi

if ( grep -q "bgfile.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	BG_FILE=$(awk -v last=bgfile.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "bgfile.${LAST_CONFIG} $BG_FILE" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
fi

if ( grep -q "cameradev.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	TMP_V4L2SRC_CAMERA=$(awk -v last=cameradev.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	eval "V4L2SRC_CAMERA=\${TMP_V4L2SRC_CAMERA}"
else
	echo "cameradev.${LAST_CONFIG} /dev/video1" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
fi

if ( grep -q "camerares.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	CAMERA_RESOLUTION=$(awk -v last=camerares.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "camerares.${LAST_CONFIG} 1280x720" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	CAMERA_RESOLUTION=1280x720
fi

if ( grep -q "camerapos.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	OVERLAY_CAMERA_POS=$(awk -v last=camerapos.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "camerapos.${LAST_CONFIG} topleft" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	OVERLAY_CAMERA_POS=topleft
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

	# Set camera output
	CAMERA_IN_WIDTH=$((${CAMERA_RESOLUTION%x*}))
	CAMERA_IN_HEIGHT=$((${CAMERA_RESOLUTION#*x}))

	# Set bitrates
	AUDIO_TARGET_BITRATE=$(($AUDIO_BIT_RATE*1000))

	VIDEO_PEAK_BITRATE=$( echo "scale=0; $VIDEO_PEAK_BITRATE_MBPS * 1000000 - $AUDIO_BIT_RATE * 1000" | bc -l )
	VIDEO_PEAK_BITRATE=$((${VIDEO_PEAK_BITRATE%.*}))

	VIDEO_TARGET_BITRATE=$( echo "scale=0; $VIDEO_PEAK_BITRATE * $RATIO_BITRATE" | bc -l )
	VIDEO_TARGET_BITRATE=$((${VIDEO_TARGET_BITRATE%.*}))

	FRAMES_PER_SEC="$(($INPUT_FRAMERATE))/1"
	I_FRAME_INTERVAL=$(($INPUT_FRAMERATE*2))

	if ( grep -q "pixelaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		PIXEL_ASPECT_RATIO=$(awk -v last=pixelaspect.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi

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
	echo "\t\tKeyframe interval=$I_FRAME_INTERVAL"
	echo "\t\tVideo H.264 peak bitrate per second=$VIDEO_PEAK_BITRATE"
	echo "\t\tVideo H.264 target bitrate bits per second=$VIDEO_TARGET_BITRATE"
	echo "\t\tAudio AAC bitrate bits per second=$AUDIO_TARGET_BITRATE\n"
	echo "\tRecording video:"
	echo "\t\tRecord video=$RECORD_VIDEO"
	echo "\t\tRecording directory=$FILE_PATH\n"
	echo "\tBackground image(animation):"
	echo "\t\tBackground=$BACKGROUND"
	echo "\t\tBG path=$BG_PATH"
	echo "\t\tBG file (printf format)=$BG_FILE\n"
	echo "\tCamera device:"
	echo "\t\tCamera input device=$V4L2SRC_CAMERA"
	echo "\t\tCamera input resolution=$CAMERA_RESOLUTION"
	echo "\t\tCamera position=$OVERLAY_CAMERA_POS"
	# Break for v4l2-ctl
	for c in `seq 1 7`; do
		sleep 1
		echo "Please, wait $c seconds!"
	done
	# Ask
	echo "\n================================================================================"
	echo "Your current configuration is set to no. $LAST_CONFIG"
	echo "================================================================================"
	echo "PLEASE, SCROLL UP AND CHECK THE STREAM SETTINGS BEFORE YOU PROCEED!\n"
	echo "Do your want to proceed and 'START' streaming or"
	echo "do you want to 'change' the video settings or"
	echo "do you want to 'quit'?"
	echo "================================================================================"
	echo "ENTER: The keywords 'START' (in upper cases) for streaming, 'change' to change"
	echo " the video configuration or 'quit' to abort the script:"
	read ASK_FOR_TASK
	case $ASK_FOR_TASK in
		quit) exit
		;;
		START) break
		;;
		change) # List current configuration and ask to create new or edit current

		# Count number of individual video configs
		CONFIG_COUNT=0
		VIDEO_CONFIG_LENGTH=`awk 'END{print NR}' $CONFIG_DIR/$VIDEO_CONFIG_FILE`
		for j in `seq 1 $VIDEO_CONFIG_LENGTH` ; do
			FIRST_STRING=$( awk -v n=$j 'NR==n { print $1 }' $CONFIG_DIR/$VIDEO_CONFIG_FILE )
			if [ "$FIRST_STRING" = "last.config" ]; then
				eval "FIRST_STRING=\${CONFIG_FIGURE}"
			elif [ "${FIRST_STRING%.*}" = "videodev" ]; then
				CONFIG_COUNT=${FIRST_STRING#*.}
			fi
		done

		echo "\n================================================================================"
		echo "\t$CONFIG_COUNT video configurations found."
		echo "================================================================================"
		# List presets
		for k in `seq 1 $CONFIG_COUNT` ; do
			if ( grep -q "videodev.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_VIDEODEV=$(awk -v last=videodev.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				CONFIG_FIGURE=$k
			else
				unset CONFIG_FIGURE # CONFIG_FIGURE=""
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
			if ( grep -q "record.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_RECORD_VIDEO=$(awk -v last=record.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "filepath.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_FILE_PATH=$(awk -v last=filepath.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "background.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_BACKGROUND=$(awk -v last=background.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "bgpath.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_BG_PATH=$(awk -v last=bgpath.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "bgfile.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_BG_FILE=$(awk -v last=bgfile.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "cameradev.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_CAMERADEV=$(awk -v last=cameradev.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "camerares.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_CAMERA_RESOLUTION=$(awk -v last=camerares.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi
			if ( grep -q "camerapos.$k" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
				PRINT_OVERLAY_CAMERA_POS=$(awk -v last=camerapos.$k 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			fi

			if [ $CONFIG_FIGURE ]; then
				echo "$k) $PRINT_VIDEODEV $PRINT_SCREEN_RESOLUTION@$PRINT_FRAMERATE ($PRINT_SCREEN_ASPECT_RATIO) -> $PRINT_DISPLAY_RESOLUTION@$PRINT_FRAMERATE ($PRINT_DISPLAY_ASPECT_RATIO) > $PRINT_VIDEO_PEAK_BITRATE mbps"
				echo "\tcrop input size=$PRINT_FLAG_CROP, brightness=$PRINT_BRIGHTNESS, contrast=$PRINT_CONTRAST, hue=$PRINT_HUE, saturation=$PRINT_SATURATION"
				echo "\trecord=$PRINT_RECORD_VIDEO directory=$PRINT_FILE_PATH"
				echo "\tbackground image (animation)=$PRINT_BACKGROUND"
				echo "\tbackground file path=$PRINT_BG_PATH"
				echo "\tbackground file=$PRINT_BG_FILE"
				echo "\tcamera=$PRINT_CAMERADEV"
				echo "\tcamera res=$PRINT_CAMERA_RESOLUTION"
				echo "\tcamera pos=$PRINT_OVERLAY_CAMERA_POS"
			fi
		done

		NEW_PRESET=$( echo "scale=0; $CONFIG_COUNT + 1" | bc -l )
		TEST_EMPTY=$( awk -v last=deleted. 'BEGIN {pattern = last ltr} $1 ~ pattern { print $1; exit }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
		if [ -z != $TEST_EMPTY ]; then
			DELETE_STRING=$(awk -v last=deleted. 'BEGIN {pattern = last ltr} $1 ~ pattern { print $1; exit }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
			EMPTY_FIGURE=${DELETE_STRING#*.}
			eval "NEW_PRESET=\${EMPTY_FIGURE}"
			unset TEST_EMPTY
		fi
		echo "$NEW_PRESET) NEW (Create a new preset)"
		echo "================================================================================"
		echo "Your current configuration is set to no. $LAST_CONFIG"
		echo "================================================================================"
		echo "ENTER: You can delete the current preset with by typing 'DELETE' (in upper"
		echo " cases) or enter the number of the preset you want to switch to or"
		echo " create a new one:"
		read CHOOSE_FIGURE
		if [ "$CHOOSE_FIGURE" != "DELETE" ]; then
			if [ $CHOOSE_FIGURE -ge 1 ] && [ $CHOOSE_FIGURE -le $CONFIG_FIGURE ] && [ $CHOOSE_FIGURE -ne $NEW_PRESET ]; then
				eval "LAST_CONFIG=\${CHOOSE_FIGURE}"
				sed -i "/last.config/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				echo "last.config $CHOOSE_FIGURE" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

				sed -i "/deleted.|$CHOOSE_FIGURE|/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE

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
				if ( grep -q "record.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
					RECORD_VIDEO=$(awk -v last=record.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				fi
				if ( grep -q "filepath.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
					FILE_PATH=$(awk -v last=filepath.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				fi
				if ( grep -q "background.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
					BACKGROUND=$(awk -v last=background.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				fi
				if ( grep -q "bgpath.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
					BG_PATH=$(awk -v last=bgpath.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				fi
				if ( grep -q "bgfile.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
					BG_FILE=$(awk -v last=bgfile.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				fi
				if ( grep -q "camersdev.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
					V4L2SRC_CAMERA=$(awk -v last=cameradev.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				fi
				if ( grep -q "camerares.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
					CAMERA_RESOLUTION=$(awk -v last=camerares.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				fi
				if ( grep -q "camerapos.$CHOOSE_FIGURE" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
					OVERLAY_CAMERA_POS=$(awk -v last=camerapos.$CHOOSE_FIGURE 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
				fi
			fi
		fi
		if [ "$CHOOSE_FIGURE" = "$NEW_PRESET" ] ; then
			eval "LAST_CONFIG=\${NEW_PRESET}"
			sed -i "/last.config/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			echo "last.config $LAST_CONFIG" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

			# Create new preset
			# Set video device
			while [ true ] ; do
				echo "================================================================================"
				echo "\tYOU CAN USE ANY HDMI CAPTURE DEVICE WITH MJPEG VIDEO OUT,"
				echo "\tE. G. Macro Silicon 2109 HDMI Video Capture USB works very well!\n"
				echo "List of capture devices:"
				v4l2-ctl --list-devices
				echo "Found video input source:"
				echo "\t\c"
				v4l2-ctl --list-devices | awk '/Video/ { getline; print $1}'
				echo "\nDo you want to use this video device for main video in or another device?"
				echo "To set another device enter the path, e. g. '/dev/video1' and enter.\n"
				echo "================================================================================"
				echo "\tCurrent MAIN VIDEO (INPUT) set to: $V4L2SRC_DEVICE"
				echo "================================================================================"
				echo "ENTER: 'yes' or the path to another device:"
				read OTHER_V4L2SRC_DEVICE
				if [ "${OTHER_V4L2SRC_DEVICE}" = "yes" ]; then
					sed -i "/videodev.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
					echo "videodev.${LAST_CONFIG} $V4L2SRC_DEVICE" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
					echo "Set Video for Linux 2 input device to: $V4L2SRC_DEVICE\n"
					break
				elif [ -e "${OTHER_V4L2SRC_DEVICE}" ]; then
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
				echo " 1) 16:9 1920x1080 - Full HD, aspect 16:9 wide"
				echo " 2)  16:9 1360x768 - HD Ready, aspect 16:9 wide"
				echo " 3)  16:9 1280x720 - HD Ready, aspect 16:9 wide"
				echo " 4)   16:9 720x576 - PAL50/60, aspect 16:9 wide"
				echo " 5)    4:3 720x576 - PAL50/60, aspect 4:3"
				echo " 6)   16:9 720x480 - NTSC, aspect 16:9 wide"
				echo " 7)    4:3 720x480 - NTSC, aspect 4:3"
				echo " 8)   16:9 640x480 - SDTV, aspect 16:9 wide"
				echo " 9)    4:3 640x480 - SDTV, aspect 4:3"
				echo "================================================================================"
				echo "Choose an INPUT resolution from the table."
				echo "ENTER: Type the number and press ENTER:"
				read RESOLUTION_TABLE_IN
				if [ $RESOLUTION_TABLE_IN -ge 1 ] && [ $RESOLUTION_TABLE_IN -le 9 ]; then
					case $RESOLUTION_TABLE_IN in
						1) TMP_SCREEN_RESOLUTION_=1920x1080
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=16:9
						;;
						2) TMP_SCREEN_RESOLUTION_=1360x768
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=16:9
						;;
						3) TMP_SCREEN_RESOLUTION_=1280x720
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=16:9
						;;
						4) TMP_SCREEN_RESOLUTION_=720x576
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=16:9
						;;
						5) TMP_SCREEN_RESOLUTION_=720x576
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=4:3
						;;
						6) TMP_SCREEN_RESOLUTION_=720x480
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=16:9
						;;
						7) TMP_SCREEN_RESOLUTION_=720x480
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=4:3
						;;
						8) TMP_SCREEN_RESOLUTION_=640x480
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=16:9
						;;
						9) TMP_SCREEN_RESOLUTION_=640x480
						TMP_INPUT_FRAMERATE_=30
						TMP_SCREEN_ASPECT_RATIO_=4:3
						;;
					esac
					echo "================================================================================"
					echo "Screen resolution (input) set to: $TMP_SCREEN_RESOLUTION_@$TMP_INPUT_FRAMERATE_"
					echo "================================================================================\n"

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
				echo "\tYOU HAVE TO CROP OLD ANALOG PAL/NTSC, COMPONENT VIDEO SIGNALS"
				echo "\t\t FROM OG. XBOX, PLAYSTATION 1/2 OR NINTENDO!\n"
				echo "Do you want to crop the border of the picture of the video input?"
				echo "The picture will be cropped about 3.5% of its border, e. g. for PAL/NTSC"
				echo "analog signals from an analog to hdmi converter."
				echo "Write 'yes'to crop image and 'no' for source, as it is, e. g. HD input signal."
				echo "================================================================================"
				echo "Crop input frames?"
				echo "ENTER: Type 'YES' (in upper cases) or 'no' and ENTER:"
				read ASK_FOR_CROP
				case $ASK_FOR_CROP in
					YES) TMP_FLAG_CROP_="yes"
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
				echo "Output resolutions (sets out-/input framerate!):\n"
				echo " 1) 1920x1080@30 - Full HD, aspect 16:9, with 30 frames per second\n"
				echo " 2) 1280x720@30 - HD Ready, aspect 16:9, with 30 frames per second"
				echo "================================================================================"
				echo "Choose an OUTPUT resolution from the table."
				echo "ENTER: Type the number and press ENTER:"
				read RESOLUTION_TABLE_OUT
				if [ $RESOLUTION_TABLE_OUT -ge 1 ] && [ $RESOLUTION_TABLE_OUT -le 2 ]; then
					case $RESOLUTION_TABLE_OUT in
						1) TMP_DISPLAY_RESOLUTION_=1920x1080
						TMP_DISPLAY_ASPECT_RATIO_=16:9
						TMP_OUTPUT_FRAMERATE_=30
						TMP_VIDEO_PEAK_BITRATE_MBPS_=4.5
						;;
						2) TMP_DISPLAY_RESOLUTION_=1280x720
						TMP_DISPLAY_ASPECT_RATIO_=16:9
						TMP_OUTPUT_FRAMERATE_=30
						TMP_VIDEO_PEAK_BITRATE_MBPS_=3.5
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
			# Adjust picture
			TMP_BRIGHTNESS_=0
			TMP_CONTRAST_=0
			TMP_SATURATION_=0
			TMP_HUE_=0

			# Implemented, but not working!
			while [ true ]; do
				#
				echo "================================================================================"
				echo "Set picture settings:\n"
				echo "\tbrightness=$TMP_BRIGHTNESS_\t(value: -2147483648 < 0 > 2147483648)"
				echo "\tcontrast=$TMP_CONTRAST_\t(value: -2147483648 < 0 > 2147483648)"
				echo "\tsaturation=$TMP_SATURATION_\t(value: -2147483648 < 0 > 2147483648)"
				echo "\thue=$TMP_HUE_\t(value: -2147483648 < 0 > 2147483648)\n"
				echo "Check if your video game console outputs limited or extended RGB color range!"
				echo "Check if your TV, monitor handles limited or (extended) RGB color on screen!"
				echo "Limited RGB input will be streched on TVs, monitors with (extended) RGB color"
				echo "enabled. The picture may look brighter than it comes from the console onscreen!"
				echo "That's because limited RGB limits the range of the color values from 16 to 235."
				echo "Extended RGB hasn't this limit, the range goes from 0 to 255."
				echo "================================================================================"
				echo "Adjust brightness, contrast, saturation and hue of the frame grabber."
				echo "================================================================================"
				echo "\tEnter a value in the range of -2147483648 to 2147483648."
				echo "\tThe default value is '0'!\n"
				echo
				echo "PICTURE SETTING IS IMPLEMENTED, BUT THERE ARE SOME PROBLEMS WITH THE GSTREAMER"
				echo " PLUGINS! MAYBE IN A FUTURE RELEASE."
				echo "YOU CAN USE AN EXTERNAL VIDEO EQUALIZER, IF YOU HAVE ONE OR YOUR SIGNAL TO HDMI"
				echo " CONVERTER, e. g. OSSC HARDWARE, HAS ONE."
				echo "All values set to zero by default!\n"

				# Stops execution of this part of the program
				break
				# Uncomment command for development and testing

					while [ true ]; do
						echo "Enter a value BRIGHTNESS=\c"
						read TMP_BRIGHTNESS_
						if [ $TMP_BRIGHTNESS_ -ge -2147483648 ] && [ $TMP_BRIGHTNESS_ -le 2147483648 ]; then
							break
						else
							echo "Brightness value out of range ('-2147483648' < '0' < '2147483648')"
						fi
					done
					while [ true ]; do
						echo "Enter a value CONTRAST=\c"
						read TMP_CONTRAST_
						if [ $TMP_CONTRAST_ -ge -2147483648 ] && [ $TMP_CONTRAST_ -le 2147483648 ]; then
							break
						else
							echo "Contrast value out of range ('-2147483648' < '0' < '2147483648')"
						fi
					done
					while [ true ]; do
						echo "Enter a value SATURATION=\c"
						read TMP_SATURATION_
						if [ $TMP_SATURATION_ -ge -2147483648 ] && [ $TMP_SATURATION_ -le 2147483648 ]; then
							break
						else
							echo "Saturation value out of range ('-2147483648' < '0' < '2147483648')"
						fi
					done
					while [ true ]; do
						echo "Enter a value HUE=\c"
						read TMP_HUE_
						if [ $TMP_HUE_ -ge -2147483648 ] && [ $TMP_HUE_ -le 2147483648 ]; then
							break
						else
							echo "Hue value out of range ('-2147483648' < '0' < '2147483648')"
						fi
					done


					echo "================================================================================"
					echo "\nYou can 'test' the picture settings with an video input signal, 'accept'"
					echo " or 'remodify' its values.\n"
					echo "'test' will write a 10 seconds video test file to your home directory, which"
					echo "will be deleted afterward. Please, wait this time and don't stop the script!"
					echo "The first window will show you the video input and a mplayer window will"
					echo " show you the recorded file with your picture adjustments."
					echo "================================================================================"

					eval "BRIGHTNESS=\${TMP_BRIGHTNESS_}"
					eval "CONTRAST=\${TMP_CONTRAST_}"
					eval "SATURATION=\${TMP_SATURATION_}"
					eval "HUE=\${TMP_HUE_}"

					SCREEN_WIDTH=${SCREEN_RESOLUTION%x*}
					SCREEN_HEIGHT=${SCREEN_RESOLUTION#*x}
					DISPLAY_WIDTH=${DISPLAY_RESOLUTION%x*}
					DISPLAY_HEIGHT=${DISPLAY_RESOLUTION#*x}

					# Start a test
					gst-launch-1.0 v4l2src \
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
					! nvoverlaysink \
						overlay-x=0 \
						overlay-y=0 \
						overlay-w=$DISPLAY_WIDTH \
						overlay-h=$DISPLAY_HEIGHT \
						overlay=1 \
						overlay-depth=1 \
						sync=false \
						async=false \
					&
					# Unstable pipeline and not working
					# ! videobalance contrast=1.0 brightness=1.0 saturation=1.0 hue=0.0 \
					# pipeline unstable

					# Get the PID of the gestreamer pipeline
					PID_GSTREAMER_TEST=$!
					sleep 15
					kill -s 15 $PID_GSTREAMER_TEST
					# Exit endless loop
					break
				done
				# End of not working
					
				eval "BRIGHTNESS=\${TMP_BRIGHTNESS_}"
				sed -i "/brightness.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				echo "brightness.${LAST_CONFIG} $BRIGHTNESS" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

				eval "CONTRAST=\${TMP_CONTRAST_}"
				sed -i "/contrast.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				echo "contrast.${LAST_CONFIG} $CONTRAST" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

				eval "SATURATION=\${TMP_SATURATION_}"
				sed -i "/saturation.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				echo "saturation.${LAST_CONFIG} $SATURATION" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

				eval "HUE=\${TMP_HUE_}"
				sed -i "/hue.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				echo "hue.${LAST_CONFIG} $HUE" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
				# End of adjust picture
				# Start of compositing dialog
				while [ true ]; do
					echo "================================================================================"
					echo "You can choose between fullscreen for main video or background picture"
					echo " or animation!"
					echo "The background image or animation must be an JPEG (.jpg) image or a sequence of"
					echo " numbered JPEG images! The filname must have the format '<JPEG name>.%04d.jpg'"
					echo " or '<JPEG name>-%03d.jpg'! '%04d' will be replaced with an image sequence of"
					echo " '0000', '0001',... If you use a sequence of images the frame rate will be the"
					echo "output framerate of the stream."
					echo "If you don't choose an background the black standard background in the config"
					echo " directory will be used for 4:3 aspect ratio video in a 16:9 HD stream."
					echo "================================================================================"
					echo "ENTER: Do you want to have a border and an background image, enter 'yes' or 'no'"
					read ASK_FOR_BACKGROUND
					case $ASK_FOR_BACKGROUND in
						yes)	TMP_ASK_FOR_BACKGROUND_="yes"
							eval "BACKGROUND=\${TMP_ASK_FOR_BACKGROUND_}"
							sed -i "/background.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
							echo "background.${LAST_CONFIG} $TMP_ASK_FOR_BACKGROUND_" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

							while [ true ]; do
								echo "================================================================================"
								echo "IMPORTANT: Use the full path /home/<user name> and not tilde '~' for your home"
								echo " directory! For example in any case '/home/alice/Pictures/Backgrounds'."
								echo "================================================================================"
								echo "Set a directory with the background image or the sequence of images:"
								read TMP_ASK_FOR_BGPATH_
								if [ -d "$TMP_ASK_FOR_BGPATH_" ]; then
									echo "Path set to:\n$TMP_ASK_FOR_BGPATH_"
									break
								fi
							done
							echo "================================================================================"
							echo "Set a background image file or sequence of JPEG images in the format explained"
							echo " before, e. g. '<JPEG name>.%04d.jpg' and the single or first file name in the"
							echo " directory must be then, e. g. <JPEG name>.0000.jpg:"
							echo "IMPORTANT: The image size must be 1920x1080 pixel!"
							echo "================================================================================"
							read TMP_ASK_FOR_BG_FILE_
							echo "Background image(s) set to:\n$TMP_ASK_FOR_BG_FILE_"

							eval "BG_PATH=\${TMP_ASK_FOR_BGPATH_}"
							sed -i "/bgpath.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
							echo "bgpath.${LAST_CONFIG} $TMP_ASK_FOR_BGPATH_" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

							eval "BG_FILE=\${TMP_ASK_FOR_BG_FILE_}"
							sed -i "/bgfile.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
							echo "bgfile.${LAST_CONFIG} $TMP_ASK_FOR_BG_FILE_" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

							break
						;;
						no)	TMP_ASK_FOR_BACKGROUND_="no"
							eval "BACKGROUND=\${TMP_ASK_FOR_BACKGROUND_}"
							sed -i "/background.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
							echo "background.${LAST_CONFIG} $TMP_ASK_FOR_BACKGROUND_" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

							sed -i "/bgpath.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
							echo "bgpath.${LAST_CONFIG} $CONFIG_DIR" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

							sed -i "/bgfile.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
							echo "bgfile.${LAST_CONFIG} bg_black.%04d.jpg" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

							break
						;;
					esac
				done
				# End of compositing dialog
				# Ask for camera
				while [ true ] ; do
					echo "================================================================================"
					echo "\t\tSETUP YOUR PICTURE IN PICTURE WEBCAM"
					echo "You need a USB webcam with MJPEG output capability, 720p 30 frames per second!"
					echo "E. g. Logitech C270, other brands may work, too. The image will be scaled.\n"
					echo "List of video devices:"
					v4l2-ctl --list-devices
					echo "Found camera:"
					v4l2-ctl --list-devices | awk '/Camera/ { getline; print $1}'
					echo "Do you want to use this video device a camera input or another device?"
					echo "To set another device enter the path, e. g. '/dev/video1' and enter.\n"
					echo "================================================================================"
					echo "\tCurrent CAMERA VIDEO (INPUT) set to: $V4L2SRC_CAMERA"
					echo "================================================================================"
					echo "ENTER: 'yes' or the path to another camera device:"
					read OTHER_V4L2SRC_CAMERA
					if [ "${OTHER_V4L2SRC_CAMERA}" = "yes" ]; then
						sed -i "/cameradev.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
						echo "cameradev.${LAST_CONFIG} $V4L2SRC_CAMERA" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
						echo "Set Video for Linux 2 camera device to: $V4L2SRC_CAMERA\n"
						break
					elif [ -e "${OTHER_V4L2SRC_CAMERA}" ]; then
						eval "V4L2SRC_CAMERA=\${OTHER_V4L2SRC_CAMERA}"
						sed -i "/cameradev.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
						echo "cameradev.${LAST_CONFIG} $V4L2SRC_CAMERA" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
						echo "Set Video for Linux 2 camera device to: $V4L2SRC_DEVICE\n"
						break
					fi
				done
				# Set input resolution
				while [ true ] ; do
					echo "================================================================================"
					echo "Please, choose a low resolution for picture in picture with game streaming!"
					echo " 640x360 should be ok.\n"
					echo "Camera input resolutions:\n"
					echo " 1) 1280x720 USB Webcam, MJPEG"
					echo " 2) 1024x576 USB Webcam, MJPEG"
					echo " 3)  800x448 USB Webcam, MJPEG"
					echo " 4)  640x360 USB Webcam, MJPEG"
					echo "================================================================================"
					echo "Choose an INPUT resolution from the table."
					echo "ENTER: Type the number and press ENTER:"
					read RESOLUTION_CAMERA_IN
					if [ $RESOLUTION_CAMERA_IN -ge 1 ] && [ $RESOLUTION_CAMERA_IN -le 4 ]; then
						case $RESOLUTION_CAMERA_IN in
							1) TMP_CAMERA_RESOLUTION_=1280x720
							;;
							2) TMP_CAMERA_RESOLUTION_=1024x576
							;;
							3) TMP_CAMERA_RESOLUTION_=800x448
							;;
							4) TMP_CAMERA_RESOLUTION_=640x360
							;;
						esac
						echo "================================================================================"
						echo "Camera resolution (input only) set to: $TMP_CAMERA_RESOLUTION_"
						echo "================================================================================"

						eval "CAMERA_RESOLUTION=\${TMP_CAMERA_RESOLUTION_}"
						sed -i "/camerares.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
						echo "camerares.${LAST_CONFIG} $CAMERA_RESOLUTION" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

						CAMERA_IN_WIDTH=${CAMERA_RESOLUTION%x*}
						CAMERA_IN_HEIGHT=${CAMERA_RESOLUTION#*x}

						break
					fi
				done
				# End of setting input resolution
				# Place camera PiP
				while [ true ] ; do
					echo "================================================================================"
					echo "Camera PiP position:\n"
					echo " 1) Top, left - Camera overlay"
					echo " 2) Bottom, left - Camera overlay"
					echo " 3) Top, right - Camera overlay"
					echo " 4) Bottom, right - Camera overlay"
					echo "================================================================================"
					echo "Choose a camera pip position from the table."
					echo "ENTER: Type the number and press ENTER:"
					read ASK_OVERLAY_CAMERA_POS
					if [ $ASK_OVERLAY_CAMERA_POS -ge 1 ] && [ $ASK_OVERLAY_CAMERA_POS -le 4 ]; then
						case $ASK_OVERLAY_CAMERA_POS in
							1) TMP_OVERLAY_CAMERA_POS_=topleft
							;;
							2) TMP_OVERLAY_CAMERA_POS_=bottomleft
							;;
							3) TMP_OVERLAY_CAMERA_POS_=topright
							;;
							4) TMP_OVERLAY_CAMERA_POS_=bottomright
							;;
						esac
						echo "================================================================================"
						echo "Camera overlay positioned at: $TMP_OVERLAY_CAMERA_POS_"
						echo "================================================================================"

						eval "OVERLAY_CAMERA_POS=\${TMP_OVERLAY_CAMERA_POS_}"
						sed -i "/camerapos.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
						echo "camerapos.${LAST_CONFIG} $OVERLAY_CAMERA_POS" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

						break
					fi
				done
				# End of setting camera PiP placement
				# Camera end
				# Ask for recording to file
				while [ true ]; do
					echo "================================================================================"
					echo "You can record a backup of your stream to a file!\n"
					echo "\tIF YOU USE AN USB3 HARDDISK DRIVE FOR RECORDING WITH THE"
					echo "\t NVIDIA JETSON NANO YOU MUST USE AN EXTERNAL HDD WITH AN"
					echo "\t EXTRA POWER SUPPLY OR YOU USE AN USB STICK!"
					echo "\t The drive will be mounted in the directory /media/\n"
					echo "Please, enter 'yes' or 'no'. The setting will be saved into your preset for"
					echo " future use. If you enter 'yes' you will be asked in which directory the video"
					echo " files should be saved. Enter the directory path,"
					echo " for example'/media/<your user name>/video' or '/home/<your user name>'."
					echo " Recording to SD Card is not recommended."
					echo "================================================================================"
					echo "ENTER: Do want to record your stream, 'YES' (in upper cases) or 'no':"
					read ASK_FOR_RECORDING
					case $ASK_FOR_RECORDING in
						YES)	TMP_ASK_FOR_RECORDING_="yes"
							sed -i "/record.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
							echo "record.${LAST_CONFIG} $ASK_FOR_RECORDING" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
							while [ true ]; do
								echo "Files will be saved as: $VIDEO_FILE"
								echo "ENTER: Enter the full recording path:"
								read ASK_FOR_PATH
								echo "Input: $ASK_FOR_PATH"
								if [ -d "$ASK_FOR_PATH" ]; then
									echo "Path set to:\n$ASK_FOR_PATH"
									break
								else
									echo "ERROR: $ASK_FOR_PATH is not a valid directory!"
								fi
							done
							break
						;;
						no)	TMP_ASK_FOR_RECORDING_="no"
							eval "ASK_FOR_PATH=/dev/null"
							break
						;;
					esac
				done

		eval "RECORD_VIDEO=\${TMP_ASK_FOR_RECORDING_}"
		sed -i "/record.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
		echo "record.${LAST_CONFIG} $TMP_ASK_FOR_RECORDING_" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

		eval "FILE_PATH=\${ASK_FOR_PATH}"
		sed -i "/filepath.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
		echo "filepath.${LAST_CONFIG} $FILE_PATH" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE

				# End of recording dialog
			sed -i "/deleted.$NEW_PRESET/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
			unset NEW_PRESET
				# End of create new preset

			# Delete preset	function
			elif [ "$CHOOSE_FIGURE" = "DELETE" ] && [ $LAST_CONFIG -ne 1 ]; then
				DEFAULT_CONFIG=1

				sed -i "/last.config/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				echo "last.config 1" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/videodev.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/screenres.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/screenaspect.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/displayres.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/displayaspect.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/inputframerate.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/pixelaspect.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/brightness.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/contrast.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/saturation.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/hue.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/crop.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/bitrate.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/record.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/filepath.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/background.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/bgpath.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/bgfile.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/cameradev.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/camerares.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE
				sed -i "/camerapos.$LAST_CONFIG/d" $CONFIG_DIR/$VIDEO_CONFIG_FILE

				if [ $CONFIG_COUNT -ne $LAST_CONFIG ]; then
					echo "deleted.${LAST_CONFIG}" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
				fi
				eval "LAST_CONFIG=\${DEFAULT_CONFIG}"
			fi
		echo "================================================================================"
		echo "Switched to configuration no. $LAST_CONFIG"
		echo "================================================================================"
		;;
	esac
	if ( grep -q "videodev.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		V4L2SRC_DEVICE=$(awk -v last=videodev.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "screenres.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		SCREEN_RESOLUTION=$(awk -v last=screenres.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "inputframerate.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		INPUT_FRAMERATE=$(awk -v last=inputframerate.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "screenaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		SCREEN_ASPECT_RATIO=$(awk -v last=screenaspect.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "pixelaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		PIXEL_ASPECT_RATIO=$(awk -v last=pixelaspect.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "displayres.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		DISPLAY_RESOLUTION=$(awk -v last=displayres.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "displayaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		DISPLAY_ASPECT_RATIO=$(awk -v last=displayaspect.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "bitrate.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		VIDEO_PEAK_BITRATE_MBPS=$(awk -v last=bitrate.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "crop.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		FLAG_CROP=$(awk -v last=crop.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "brightness.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		BRIGHTNESS=$(awk -v last=brightness.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "contrast.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		CONTRAST=$(awk -v last=contrast.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "hue.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		HUE=$(awk -v last=hue.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "saturation.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		SATURATION=$(awk -v last=saturation.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "record.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		RECORD_VIDEO=$(awk -v last=record.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "filepath.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		FILE_PATH=$(awk -v last=filepath.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "background.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		BACKGROUND=$(awk -v last=background.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "bgpath.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		BG_PATH=$(awk -v last=bgpath.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "bgfile.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		BG_FILE=$(awk -v last=bgfile.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "cameradev.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		V4L2SRC_CAMERA=$(awk -v last=cameradev.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "camerares.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		CAMERA_RESOLUTION=$(awk -v last=camerares.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
	if ( grep -q "camerapos.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
		OVERLAY_CAMERA_POS=$(awk -v last=camerapos.$LAST_CONFIG 'BEGIN {pattern = last ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	fi
done

# Check your webcam
gst-launch-1.0 v4l2src \
	device=$V4L2SRC_CAMERA \
	io-mode=2 \
! "image/jpeg,width=$CAMERA_IN_WIDTH,height=$CAMERA_IN_HEIGHT,framerate=${FRAMES_PER_SEC}" \
! nvjpegdec \
! "video/x-raw" \
! nvvidconv \
! "video/x-raw(memory:NVMM),format=NV12" \
! nvoverlaysink \
	overlay-x=$OVL2_POSITION_X \
	overlay-y=$OVL2_POSITION_Y \
	overlay-w=$OVL2_SIZE_X \
	overlay-h=$OVL2_SIZE_Y \
	overlay=2 \
	overlay-depth=1 \
	sync=false \
	async=false \
&
# Get the PID of the gestreamer pipeline
PID_CAMERA_OVERLAY=$!

while [ true ]; do
	echo "================================================================================\n"
	echo "\tCheck a last time your webcam positioning with the overlay!\n"
	echo "================================================================================"
	echo "Type 'ok' after you've checked the webcam positioning or 'quit' to exit!"
	echo "================================================================================"
	echo "ENTER: 'ok' or 'quit'and ENTER:"
	read ASK_WEBCAM_CHECK
	if [ "$ASK_WEBCAM_CHECK" = "ok" ]; then
		# Close overlay
		kill -s 15 $PID_CAMERA_OVERLAY
		break
	elif [ "$ASK_WEBCAM_CHECK" = "quit" ]; then
		# Close overlay
		kill -s 15 $PID_CAMERA_OVERLAY
		exit
	fi
done

# Close overlay
kill -s 15 $PID_CAMERA_OVERLAY

for d in `seq 1 7`; do
	sleep 1
	echo "Please, wait $d seconds!"
done

# Wake up drive from sleep state (in case of magnetic HDD)
ls -alh $FILE_PATH

# Flush the toilet
gst-launch-1.0 v4l2src device=$V4L2SRC_DEVICE io-mode=2 \
! videoconvert \
! xvimagesink &

PID_GSTREAMER_V4L2SRC_PREVIEW=$!

for b in `seq 1 10`; do
	sleep 1
	echo "Please, wait ten seconds, $b, resetting the the NV hardware de-/encoders!"
done
kill -s 15 $PID_GSTREAMER_V4L2SRC_PREVIEW
# Flushed, NVENC, NVDEC and NVJPEG cores resetted

for a in `seq 1 7`; do
	sleep 1
	echo "Please, wait $a seconds!"
done

while [ true ]; do
	echo "================================================================================"
	echo "\tUse the Twitch.tv app for mobile device with your Twitch.tv"
	echo "\t account or use a browser to set your stream name and what"
	echo "\t you want to stream, e. g. the name of the video game,"
	echo "\t retro gaming, RL, science or a hobby.\n"
	echo "\tCheck your desktop audio mixer of the NVIDIA Jetson Nano and mute or"
	echo "\t disable unused Pulseaudio sources!\n"
	echo "\tCheck your stream with the Twitch app for mobile devices!"
	echo "================================================================================"
	echo "Type one more time the word 'START' (in upper cases) to begin streaming!"
	echo "================================================================================"
	echo "ENTER: 'START' (in upper cases) or 'quit'and ENTER:"
	read ASK_FINAL_START_STREAMING
	if [ "$ASK_FINAL_START_STREAMING" = "START" ]; then
		break
	elif [ "$ASK_FINAL_START_STREAMING" = "quit" ]; then
		exit
	fi
done

if [ "$RECORD_VIDEO" = "yes" ]; then
	FILE_PATH="${FILE_PATH}/${VIDEO_FILE}"
else
	FILE_PATH=/dev/null
fi
echo "Recording to: $FILE_PATH"

if [ "$DISPLAY_RESOLUTION" = "1920x1080" ]; then
	CAM_WIDTH=480
	CAM_HEIGHT=270
else
	CAM_WIDTH=320
	CAM_HEIGHT=180
fi

if [ "$OVERLAY_CAMERA_POS" = "topleft" ]; then
	CAM_POS_X=0
	CAM_POS_Y=0
elif [ "$OVERLAY_CAMERA_POS" = "bottomleft" ]; then
	CAM_POS_X=0
	CAM_POS_Y=$( echo "scale=0; $DISPLAY_HEIGHT - $CAM_HEIGHT" | bc -l )
elif [ "$OVERLAY_CAMERA_POS" = "topright" ]; then
	CAM_POS_X=$( echo "scale=0; $DISPLAY_WIDTH - $CAM_WIDTH" | bc -l )
	CAM_POS_Y=0
elif [ "$OVERLAY_CAMERA_POS" = "bottomright" ]; then
	CAM_POS_X=$( echo "scale=0; $DISPLAY_WIDTH - $CAM_WIDTH" | bc -l )
	CAM_POS_Y=$( echo "scale=0; $DISPLAY_HEIGHT - $CAM_HEIGHT" | bc -l )
fi

if [ "$BACKGROUND" = "no" ] && [ "$SCREEN_ASPECT_RATIO" = "16:9" ] && [ "$DISPLAY_RESOLUTION" = "1920x1080" ]; then
	VIEW_POS_X=0
	VIEW_POS_Y=0
	VIEW_WIDTH=$DISPLAY_WIDTH
	VIEW_HEIGHT=$DISPLAY_HEIGHT
elif [ "$BACKGROUND" = "no" ] && [ "$SCREEN_ASPECT_RATIO" = "16:9" ] && [ "$DISPLAY_RESOLUTION" = "1280x720" ]; then
	VIEW_POS_X=0
	VIEW_POS_Y=0
	VIEW_WIDTH=$DISPLAY_WIDTH
	VIEW_HEIGHT=$DISPLAY_HEIGHT
elif [ "$BACKGROUND" = "yes" ] && [ "$SCREEN_ASPECT_RATIO" = "16:9" ] && [ "$DISPLAY_RESOLUTION" = "1920x1080" ]; then
	VIEW_POS_X=160
	VIEW_POS_Y=90
	VIEW_WIDTH=1600
	VIEW_HEIGHT=900
elif [ "$BACKGROUND" = "yes" ] && [ "$SCREEN_ASPECT_RATIO" = "16:9" ] && [ "$DISPLAY_RESOLUTION" = "1280x720" ]; then
	VIEW_POS_X=160
	VIEW_POS_Y=90
	VIEW_WIDTH=960
	VIEW_HEIGHT=540
elif [ "$SCREEN_ASPECT_RATIO" = "4:3" ] && [ "$DISPLAY_RESOLUTION" = "1920x1080" ]; then
	VIEW_POS_X=320
	VIEW_POS_Y=90
	VIEW_WIDTH=1280
	VIEW_HEIGHT=900
elif [ "$SCREEN_ASPECT_RATIO" = "4:3" ] && [ "$DISPLAY_RESOLUTION" = "1280x720" ]; then
	VIEW_POS_X=160
	VIEW_POS_Y=90
	VIEW_WIDTH=800
	VIEW_HEIGHT=540
fi

# Set fix pixel aspect ratio of PIXEL_ASPECT_RATIO_GSTREAMER="1/1"
eval "PIXEL_ASPECT_RATIO_GSTREAMER=\1/1"

# For testing purpose switch the av pipeline output to filesink. It's very important to verify the
# output frame rate of the stream. Test the frame rate with of the video.mp4 file with mplayer!
#
# ! filesink location="/media/marc/data/video/gamecapture/test/video.mp4"  sync=false async=false \
#
# and for streaming back to
#
# ! rtmpsink location="$LIVE_SERVER$STREAM_KEY?bandwidth_test=false" sync=false async=false \
#
# GStreamer v4l2src with mjpeg must have the mmap option enabled!
gst-launch-1.0 nvcompositor name=comp \
sink_0::xpos=0 sink_0::ypos=0 sink_0::width=$DISPLAY_WIDTH sink_0::height=$DISPLAY_HEIGHT \
sink_1::xpos=$VIEW_POS_X sink_1::ypos=$VIEW_POS_Y sink_1::width=$VIEW_WIDTH sink_1::height=$VIEW_HEIGHT \
sink_2::xpos=$CAM_POS_X sink_2::ypos=$CAM_POS_Y sink_2::width=$CAM_WIDTH sink_2::=$CAM_HEIGHT \
! "video/x-raw(memory:NVMM),framerate=${FRAMES_PER_SEC}" \
! nvvidconv interpolation-method=$SCALER_TYPE \
! "video/x-raw(memory:NVMM),width=${DISPLAY_WIDTH},height=${DISPLAY_HEIGHT}" \
! omxh264enc iframeinterval=$I_FRAME_INTERVAL \
	bitrate=$VIDEO_TARGET_BITRATE \
	peak-bitrate=$VIDEO_PEAK_BITRATE \
	control-rate=$CONTROL_RATE \
	preset-level=$VIDEO_QUALITY \
	profile=$H264_PROFILE \
	cabac-entropy-coding=$CABAC \
! "video/x-h264,stream-format=byte-stream,framerate=${FRAMES_PER_SEC}" \
! h264parse config-interval=-1 \
! flvmux \
	start-time-selection=1 \
	latency=7000000000 \
	streamable=true \
	metadatacreator="NVIDIA Jetson Nano/GStreamer 1.14.5 FLV muxer" \
	name=mux \
! tee name=container0 \
! queue \
! rtmpsink location="$LIVE_SERVER$STREAM_KEY?bandwidth_test=false" sync=false async=false \
\
multifilesrc location="${BG_PATH}/${BG_FILE}" \
	index=0 caps="image/jpeg" \
	loop=true \
! "image/jpeg,width=1920,height=1080" \
! jpegparse \
! nvjpegdec \
! "video/x-raw" \
! nvvidconv \
! "video/x-raw(memory:NVMM),format=NV12" \
! nvvidconv interpolation-method=$SCALER_TYPE \
! "video/x-raw(memory:NVMM),width=${DISPLAY_WIDTH},height=${DISPLAY_HEIGHT}" \
! queue \
! comp. \
\
v4l2src \
	brightness=$BRIGHTNESS \
	contrast=$CONTRAST \
	device=$V4L2SRC_DEVICE \
	hue=$HUE \
	pixel-aspect-ratio=$PIXEL_ASPECT_RATIO_GSTREAMER \
	saturation=$SATURATION \
	io-mode=2 \
! "image/jpeg,width=${SCREEN_WIDTH},height=${SCREEN_HEIGHT},framerate=${FRAMES_PER_SEC}" \
! nvjpegdec \
! "video/x-raw" \
! nvvidconv \
! "video/x-raw(memory:NVMM),format=NV12" \
! nvvidconv left=$CROP_X0 right=$CROP_X1 top=$CROP_Y0 bottom=$CROP_Y1 \
! nvvidconv interpolation-method=$SCALER_TYPE \
! "video/x-raw(memory:NVMM),width=${VIEW_WIDTH},height=${VIEW_HEIGHT}" \
! tee name=videosrc0 \
! queue \
! comp. \
\
v4l2src \
	device=$V4L2SRC_CAMERA \
	io-mode=2 \
! "image/jpeg,width=$CAMERA_IN_WIDTH,height=$CAMERA_IN_HEIGHT,framerate=${FRAMES_PER_SEC}" \
! jpegparse \
! nvjpegdec \
! "video/x-raw" \
! nvvidconv \
! "video/x-raw(memory:NVMM),format=NV12" \
! nvvidconv interpolation-method=$SCALER_TYPE \
! "video/x-raw(memory:NVMM),width=$CAM_WIDTH,height=$CAM_HEIGHT" \
! tee name=videocam0 \
! queue \
! comp. \
\
alsasrc \
! "audio/x-raw,format=S16LE,layout=interleaved, rate=${AUDIO_SAMPLING_RATE}, channels=${AUDIO_NUM_CH}" \
! voaacenc bitrate=$AUDIO_BIT_RATE \
! aacparse \
! queue \
! mux. \
\
videosrc0. \
! nvoverlaysink \
	overlay-x=$OVL1_POSITION_X \
	overlay-y=$OVL1_POSITION_Y \
	overlay-w=$OVL1_SIZE_X \
	overlay-h=$OVL1_SIZE_Y \
	overlay=1 \
	overlay-depth=1 \
	sync=false \
	async=false \
\
videocam0. \
! nvoverlaysink \
	overlay-x=$OVL2_POSITION_X \
	overlay-y=$OVL2_POSITION_Y \
	overlay-w=$OVL2_SIZE_X \
	overlay-h=$OVL2_SIZE_Y \
	overlay=2 \
	overlay-depth=1 \
	sync=false \
	async=false \
\
container0. \
! queue \
! filesink location=$FILE_PATH > $CONFIG_DIR/gstreamer-debug-out.log \
&

# Get the PID of the gestreamer pipeline
PID_GSTREAMER_PIPELINE=$!

echo "\nWriting GStreamer debug log into:"
echo "\t$CONFIG_DIR/gstreamer-debug-out.log"

# Pipline and stream started
if [ `pidof gst-launch-1.0` = $PID_GSTREAMER_PIPELINE ]; then
	echo "\n\tYOU'RE STREAM IS NOW ONLINE & LIVE!\n"
fi

sleep 5

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
