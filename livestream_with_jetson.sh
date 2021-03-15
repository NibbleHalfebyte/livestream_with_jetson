#!/bin/sh
#
# File: livestream_with_jetson_v0.04.sh 
# Date: 2021-03-15
# Version 0.04d by Marc Bayer
#
# Script for video live streaming to Twitch, YT, FB
# with NVidia Jetson Nano embedded computer
#
# Usage: jetson_nano2livestream_twitch.sh
#	Exchange <your_live_streaming_key> with your Twitch stream key
#	for example STREAM_KEY="live_12345678901234567890"
# 	and copy and paste a server from https://stream.twitch.tv/ingests/
#	to <see_server_list_for_your_country>,
#	e. g. LIVE_SERVER="rtmp://sfo.contribute.live-video.net/app/".
#	The MS2109 HDMI2USB is limited to 720p with 60 fps and
#	1080p with 30 fps.
#
# MacroSilicon MS2109 USB stick - uvcvideo kernel module
# For stereo sound with pulsaudio try Stary's blog:
# https://9net.org/.../hdmi-capture-without-breaking-the-bank/
# 1920p30/60 capture doesn't work with this script with audio and overlay
# and try to excute the script with nice
#
# v4l2-ctl -d /dev/video0 --list-formats-ext

# Create some files
CONFIG_DIR=~/.config/livestream_with_jetson_conf
STREAM_KEY_FILE=live_stream_with_jetson_stream.key

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
echo "\nStream key not found in"
echo "\t$CONFIG_DIR/$STREAM_KEY_FILE\n"
# Create empty stream key file
touch $CONFIG_DIR/$STREAM_KEY_FILE
chmod o-r $CONFIG_DIR/$STREAM_KEY_FILE
elif [ $CONFIG_DIR/$STREAM_KEY_FILE ]; then
echo "\nStream key found in:"
echo "\t$CONFIG_DIR/$STREAM_KEY_FILE\n"
fi

# Check if stream key is empty
if [ `find $CONFIG_DIR -empty -name $STREAM_KEY_FILE` ]; then
/usr/bin/chromium-browser "https://www.twitch.tv/login" &
sleep 1
echo "Please, enter your Twitch.tv stream key from your Twitch account.\n"
echo "The key will be saved in this file: $STREAM_KEY_FILE"
echo "Your will find the stream key file in this directory: $CONFIG_DIR\n"
echo "ENTER OR COPY THE STREAM KEY INTO THIS COMMAND LINE:\n"
read CREATE_STREAM_KEY
echo $CREATE_STREAM_KEY > $CONFIG_DIR/$STREAM_KEY_FILE
else
echo "FILE WITH STREAM KEY $STREAM_KEY_FILE"
echo "\tWAS FOUND IN $CONFIG_DIR"
fi

while [ true ]; do
echo "\nDo you want to (re)enter a new stream key?"
echo "Enter 'YES' (in upper case) or 'no'."
read CHANGE_KEY
case $CHANGE_KEY in
	YES) /usr/bin/chromium-browser "https://www.twitch.tv/login" &
	     sleep 1
	     echo "Please, enter your Twitch.tv stream key from your Twitch account.\n"
	     echo "The key will be saved in this file: $STREAM_KEY_FILE"
	     echo "Your will find the stream key file in this directory: $CONFIG_DIR\n"
	     echo "ENTER OR COPY THE STREAM KEY INTO THIS COMMAND LINE:\n"
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

# Stream key for Twitch (or FB, YT (not tested))
STREAM_KEY=$(cat $CONFIG_DIR/$STREAM_KEY_FILE)
#echo "(For debugging only!) Your stream key is: $STREAM_KEY\n"

# Twitch server for your country, see https://stream.twitch.tv/ingests/
# e. g. Berlin, Europe, rtmp://ber.contribute.live-video.net/app/
# e. g. Houston, USA, rtmp://hou.contribute.live-video.net/app/
# LIVE_SERVER="rtmp://hou.contribute.live-video.net/app/"
# LIVE_SERVER="rtmp://ber.contribute.live-video.net/app/"
# LIVE_SERVER="rtmp://cdg.contribute.live-video.net/app/"
LIVE_SERVER="<see_server_list_for_your_country>"

echo "\nInput and output set to:\n"

# Video capture sources
echo "List of capture devices:"
for V4L2SRC_DEVICE in /dev/video* ; do
echo "\t$V4L2SRC_DEVICE\n"
v4l2-ctl --device=$V4L2SRC_DEVICE --list-inputs
echo
done

while [ true ] ; do
echo "Use this $V4L2SRC_DEVICE Video for Linux device and"
echo "write 'yes' and enter or write the path to another"
echo "device, e. g. '/dev/video1' and enter.\n"
read OTHER_V4L2SRC_DEVICE
if [ "${OTHER_V4L2SRC_DEVICE}" = "yes" ]; then
echo "Set Video for Linux 2 input device to: $V4L2SRC_DEVICE\n"
break
fi
if [ "${OTHER_V4L2SRC_DEVICE}" = "/dev/video1" ]; then
eval "V4L2SRC_DEVICE=\${OTHER_V4L2SRC_DEVICE}"
echo "Set Video for Linux 2 input device to: $V4L2SRC_DEVICE\n"
break
fi
done

# Audio capture sources
echo "List of audio devices:"
arecord -L | grep ^hw:
echo

# Picture settings
BRIGHTNESS=0
CONTRAST=0
HUE=0
SATURATION=0

echo "Picture settings:"
echo "\tBrightness=$BRIGHTNESS"
echo "\tContrast=$CONTRAST"
echo "\tHue=$HUE"
echo "\tSaturation=$SATURATION\n"

# Input settings
PIXEL_ASPECT_RATIO="1:1"
SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080
INPUT_FRAMERATE=30
SCREEN_ASPECT_RATIO="16:9"

SCREEN_AR_X=$((${SCREEN_ASPECT_RATIO%:*}))
SCREEN_AR_Y=$((${SCREEN_ASPECT_RATIO#*:}))

echo "Video input settings:"
echo "\tScreen width=$SCREEN_WIDTH"
echo "\tScreen height=$SCREEN_HEIGHT"
echo "\tInput framerate=$INPUT_FRAMERATE"
echo "\tScreen aspect ratio: $SCREEN_AR_X:$SCREEN_AR_Y\n"

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
# Show cropping values
echo "Screen cropped to:"
echo "\tUpper left corner coordinates"
echo "\tX0=$CROP_X0, Y0=$CROP_Y0\n"
echo "\t\tLower right corner coordinates"
echo "\t\tX1=$CROP_X1, Y1=$CROP_Y1\n"
echo "\tScreen safe area in width cropped to: $CROPPED_SCREEN_WIDTH"
echo "\tScreen safe area in height cropped to: $CROPPED_SCREEN_HEIGHT\n"

# Output settings
DISPLAY_WIDTH_MAIN=1920
DISPLAY_HEIGHT_MAIN=1080

DISPLAY_ASPECT_RATIO="16:9"

DISPLAY_AR_X=$((${DISPLAY_ASPECT_RATIO%:*}))
DISPLAY_AR_Y=$((${DISPLAY_ASPECT_RATIO#*:}))

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

echo "Video output settings:"
echo "\tDisplay aspect ratio: $DISPLAY_AR_X:$DISPLAY_AR_Y"
echo "\tVideo H.264 target bitrate bits per second: $VIDEO_TARGET_BITRATE"
echo "\tVideo H.264 peak bitrate per second: $VIDEO_PEAK_BITRATE"
echo "\tAudio AAC bitrate bits per second: $AUDIO_BIT_RATE"
echo "\tFrames per second gstreamer: $FRAMES_PER_SEC"
echo "\tKeyframe interval per frames: $I_FRAME_INTERVAL"
echo "\tPixel aspect ratio for gstreamer: $PIXEL_AR_X:$PIXEL_AR_Y\n"

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
! "video/x-raw(memory:NVMM),width=${DISPLAY_WIDTH_MAIN},height=${DISPLAY_HEIGHT_MAIN},format=NV12" \
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

sleep 1
echo "\nWriting GStreamer debug log into:"
echo "\t$CONFIG_DIR/gstreamer-debug-out.log"

# Pipline and stream started
if [ `pidof gst-launch-1.0` = $PID_GSTREAMER_PIPELINE ]; then
echo "\n\tYOU'RE STREAM IS NOW ONLINE & LIVE!\n"
fi

# Read key press for stopping gestreamer pipeline
while [ true ] ; do
echo "\tWrite the word 'quit' and enter to stop the stream!\n"
read QUIT_STREAM
if [ "${QUIT_STREAM}" = "quit" ]; then
echo "\tARE YOU REALLY SURE? PLEASE ENTER THE WORD 'quit' AGAIN!\n"
read REALLY_QUIT_STREAM
if [ "${REALLY_QUIT_STREAM}" = "quit" ]; then
break
fi
fi
done
kill -s 15 $PID_GSTREAMER_PIPELINE
echo "\tSTREAM STOPPED!\n"
