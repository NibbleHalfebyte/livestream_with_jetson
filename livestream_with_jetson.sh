#!/bin/sh
#
# File: livestream_with_jetson_v0.04.sh 
# Date: 2021-03-17
# Version 0.04h by Marc Bayer
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
	/usr/bin/chromium-browser "https://www.twitch.tv/login" &
	sleep 1
	echo "Please, enter your Twitch.tv stream key from your Twitch account.\n"
	echo "The key will be saved in this file: $STREAM_KEY_FILE"
	echo "Your will find the stream key file in this directory: $CONFIG_DIR\n"
	echo "ENTER OR COPY THE STREAM KEY INTO THIS COMMAND LINE AND PRESS RETURN:"
	read CREATE_STREAM_KEY
	echo $CREATE_STREAM_KEY > $CONFIG_DIR/$STREAM_KEY_FILE
else
	echo "FILE WITH STREAM KEY $STREAM_KEY_FILE"
	echo "\tWAS FOUND IN $CONFIG_DIR"
fi

while [ true ]; do
	echo "\nDo you want to (re)enter a new stream key?"
	echo "ENTER: 'YES' (in upper-case) or 'no'."
	read CHANGE_KEY
	echo
	case $CHANGE_KEY in
		YES) /usr/bin/chromium-browser "https://www.twitch.tv/login" &
		     sleep 1
		     echo "Please, enter your Twitch.tv stream key from your Twitch account.\n"
		     echo "The key will be saved in this file: $STREAM_KEY_FILE"
		     echo "Your will find the stream key file in this directory: $CONFIG_DIR\n"
		     echo "ENTER OR COPY THE STREAM KEY INTO THIS COMMAND LINE AND PRESS RETURN:\n"
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
		echo "Do you want to change the stream ingest server from your last session"
		echo "to another server?"
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
	for i in `seq 1 $INGEST_LIST_LENGTH` ; do
		echo | ( awk -v n=$i 'NR==n { print n").."$2, $3, $4, $5, $6, $7, $8, $1 }' $CONFIG_DIR/$INGEST_SERVER_LIST )
	done

	while [ true ]; do
		echo "Choose a number from the server list for your region,"
		echo "ENTER: Write the number before the server, e. g. 51, and press RETURN."
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

echo "List of capture devices:"
for V4L2SRC_DEVICE in /dev/video* ; do
	echo "\t$V4L2SRC_DEVICE\n"
	v4l2-ctl --device=$V4L2SRC_DEVICE --list-inputs
	echo
done

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
	TMP_V4L2SRC_DEVICE=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "videodev." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	eval "V4L2SRC_DEVICE=\${TMP_V4L2SRC_DEVICE}"
else
	echo "videodev.${LAST_CONFIG} ${V4L2SRC_DEVICE}" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
fi

if ( grep -q "screenres.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	TMP_SCREEN_RESOLUTION=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "screenres." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
	eval "SCREEN_RESOLUTION=\${TMP_SCREEN_RESOLUTION}"
else
	echo "screenres.${LAST_CONFIG} 1920x1080" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	SCREEN_RESOLUTION=1920x1080
fi

if ( grep -q "inputframerate.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	INPUT_FRAMERATE=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "inputframerate." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "inputframerate.${LAST_CONFIG} 30" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	INPUT_FRAMERATE=30
fi

if ( grep -q "screenaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	SCREEN_ASPECT_RATIO=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "screenaspect." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "screenaspect.${LAST_CONFIG} 16:9" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	SCREEN_ASPECT_RATIO=16:9
fi

if ( grep -q "pixelaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	PIXEL_ASPECT_RATIO=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "pixelaspect." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "pixelaspect.${LAST_CONFIG} 1:1" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	PIXEL_ASPECT_RATIO=1:1
fi

if ( grep -q "brightness.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	BRIGHTNESS=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "brightness." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "brightness.${LAST_CONFIG} 0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	BRIGHTNESS=0
fi

if ( grep -q "contrast.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	CONTRAST=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "contrast." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "contrast.${LAST_CONFIG} 0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	CONTRAST=0
fi

if ( grep -q "hue.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	HUE=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "hue." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "hue.${LAST_CONFIG} 0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	HUE=0
fi

if ( grep -q "saturation.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	SATURATION=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "saturation." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "saturation.${LAST_CONFIG} 0" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	SATURATION=0
fi

if ( grep -q "displayres.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	DISPLAY_RESOLUTION=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "displayres." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "displayres.${LAST_CONFIG} 1920x1080" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	DISPLAY_RESOLUTION=1920x1080
fi

if ( grep -q "displayaspect.$LAST_CONFIG" $CONFIG_DIR/$VIDEO_CONFIG_FILE ); then
	DISPLAY_ASPECT_RATIO=$(awk -v last=$LAST_CONFIG 'BEGIN {pattern = "displayaspect." ltr} $1 ~ pattern { print $2 }' "${CONFIG_DIR}/${VIDEO_CONFIG_FILE}")
else
	echo "displayaspect.${LAST_CONFIG} 16:9" >> $CONFIG_DIR/$VIDEO_CONFIG_FILE
	DISPLAY_ASPECT_RATIO=16:9
fi

# Input/output settings
echo "Current settings:"
echo "\tVideo input:"
echo "\t\tVideo input device=$V4L2SRC_DEVICE"
echo "\t\tVideo input resolution=$SCREEN_RESOLUTION"
echo "\t\tVideo capture framerate=$INPUT_FRAMERATE"
echo "\t\tVideo screen aspect ratio=$SCREEN_ASPECT_RATIO"
echo "\t\tVideo pixel aspect ratio=$PIXEL_ASPECT_RATIO" 
echo "\tPicture settings:"
echo "\t\tBrightness=$BRIGHTNESS"
echo "\t\tContrast=$CONTRAST"
echo "\t\tHue=$HUE"
echo "\t\tSaturation=$SATURATION"
echo "\tVideo output:"
echo "\t\tVideo output resolution=$DISPLAY_RESOLUTION"
echo "\t\tVideo display aspect ratio=$DISPLAY_ASPECT_RATIO"

while [ true ] ; do
	echo "Do you want to use this video device for main video in or another device?"
	echo "To set another device enter the path, e. g. '/dev/video1' and enter.\n"
	echo "\tCurrent MAIN VIDEO (INPUT) set to: $V4L2SRC_DEVICE\n"
	echo "ENTER: 'yes' or the path to another device."
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

echo "Supported formats for video device $V4L2SRC_DEVICE:"
v4l2-ctl -d $V4L2SRC_DEVICE --list-formats-ext

# Audio capture sources
echo "List of audio devices:"
arecord -L | grep ^hw:

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

# Crop image in absolute screen coordinates
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

# Scaler type for output scaling
# 0 = nearest
# 1 = bilinear
# 2 = 5-tap
# 3 = 10-tap
# 4 = smart (default)
# 5 = nicest
SCALER_TYPE=5

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

# Videoencoder bitrate in mbits per second
VIDEO_TARGET_BITRATE=4.5

# Videencoder peak bitrate in mbits per seconds
# 0 = Default: 1.2 * VIDEO_TARGET_BITRATE
VIDEO_PEAK_BITRATE=0

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

VIDEO_TARGET_BITRATE=$( echo "scale=0; $VIDEO_TARGET_BITRATE * 1000000" | bc -l )
VIDEO_TARGET_BITRATE=$((${VIDEO_TARGET_BITRATE%.*}))

AUDIO_TARGET_BITRATE=$(($AUDIO_BIT_RATE*1000))

if [ "$VIDEO_PEAK_BITRATE" = "$(echo '0')" ];
	then
		VIDEO_PEAK_BITRATE=$( echo "scale=0; $VIDEO_TARGET_BITRATE * 1.2" | bc -l )
		VIDEO_PEAK_BITRATE=$((${VIDEO_PEAK_BITRATE%.*}))
	else
		VIDEO_PEAK_BITRATE=$( echo "scale=0; $VIDEO_PEAK_BITRATE * 1000000" | bc -l )
		VIDEO_PEAK_BITRATE=$((${VIDEO_PEAK_BITRATE%.*}))
fi

FRAMES_PER_SEC="$(($INPUT_FRAMERATE))/1"
I_FRAME_INTERVAL=$(($INPUT_FRAMERATE*2))

PIXEL_AR_X=$((${PIXEL_ASPECT_RATIO%:*}))
PIXEL_AR_Y=$((${PIXEL_ASPECT_RATIO#*:}))

PIXEL_ASPECT_RATIO="$PIXEL_AR_X/$PIXEL_AR_Y"

# Overlay size
OVL_POSITION_X=100
OVL_POSITION_Y=100
OVL_SIZE_X=640
OVL_SIZE_Y=320

# Overlay size
OVL1_POSITION_X=840
OVL1_POSITION_Y=100
OVL1_SIZE_X=640
OVL1_SIZE_Y=320

# Show input settings
echo "\nVideo input settings:"
echo "\tScreen width=$SCREEN_WIDTH"
echo "\tScreen height=$SCREEN_HEIGHT"
echo "\tCapture framerate=$INPUT_FRAMERATE"
echo "\tScreen aspect ratio: $SCREEN_AR_X:$SCREEN_AR_Y"
echo "\tPixel aspect ratio: $PIXEL_AR_X:$PIXEL_AR_Y"
# Show cropping values
echo "Screen cropped to:"
echo "\tUpper left corner coordinates"
echo "\tX0=$CROP_X0, Y0=$CROP_Y0\n"
echo "\t\tLower right corner coordinates"
echo "\t\tX1=$CROP_X1, Y1=$CROP_Y1\n"
echo "\tScreen safe area in width cropped to: $CROPPED_SCREEN_WIDTH"
echo "\tScreen safe area in height cropped to: $CROPPED_SCREEN_HEIGHT"
# Show output settings
echo "Video output settings:"
echo "\tDisplay width=$DISPLAY_WIDTH"
echo "\tDisplay heigth=$DISPLAY_HEIGHT"
echo "\tOutput framerate=$INPUT_FRAMERATE"
echo "\tKeyframe interval per frames: $I_FRAME_INTERVAL"
echo "\tDisplay aspect ratio: $DISPLAY_AR_X:$DISPLAY_AR_Y\n"
echo "\tVideo H.264 target bitrate bits per second: $VIDEO_TARGET_BITRATE"
echo "\tVideo H.264 peak bitrate per second: $VIDEO_PEAK_BITRATE"
echo "\tAudio AAC bitrate bits per second: $AUDIO_BIT_RATE\n"

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
	pixel-aspect-ratio=$PIXEL_ASPECT_RATIO \
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
	echo "\tWrite the word 'quit' and enter to stop the stream!"
	echo "\tENTER: 'quit' and RETURN\n"
	read QUIT_STREAM
	if [ "${QUIT_STREAM}" = "quit" ]; then
		echo "\tARE YOU REALLY SURE? PLEASE ENTER THE WORD 'quit' AGAIN AND RETURN!\n"
		read REALLY_QUIT_STREAM
			if [ "${REALLY_QUIT_STREAM}" = "quit" ]; then
				break
			fi
	fi
done
kill -s 15 $PID_GSTREAMER_PIPELINE
echo "\tSTREAM STOPPED!\n"
