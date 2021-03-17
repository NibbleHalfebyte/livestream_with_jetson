# Video Game Capture with a NVIDIA Jetson Nano: Internet live streaming and compressed recording
Linux shell script for video live streaming to Twitch, YouTube and Facebook with a NVIDIA Jetson Nano embedded computer

For first steps you will need a NVDIA Jetson Nano 4 GB with preinstalled, hardware accelerated GStreamer. I used JetPack 4.5.1, and a 15 bucks Macro Silicon HDMI to USB video capture stick. Other HDMI capture devices, CSI2 camera connector or USB and USB sound cards, which are supported by Video 4 Linux 2 on Ubuntu Linux 18.04, may work (at your own risk).

For sound in and out you could use the Behringer UCA202 and plug in the game console, a mixer or whatever you want. It works out of the box with the NVIDIA Jetson Nano.

A Raspberry Pi 3b+ Micro-USB power supply will work, but it's better you buy a power supply with barrel jack (5.5 mm outside, 2.1 mm inside, 5 Volt, equal or greater 3 Ampere). Don't disable the WiFi power management of the Intel 8265AC M.2 WiFi module of the Jetson Nano without a heat sink on the WiFi module!

Add at the end of the default.pa file for Pulseaudio in /etc/pulse directory this line to remap the 96KHz PCM mono sound output (stereo encoded in mono) to a pulseaudio stereo source. Change master=alsa_input.usb-MACROSILICON_USB_Video-02.analog-mono to fit with your MacroSilicon 2109 usb stick.

load-module module-remap-source source_name=macrosilicon-reverse-stereo master=alsa_input.usb-MACROSILICON_USB_Video-02.analog-mono channels=2 master_channel_map=front-right,front-left channel_map=front-left,front-right

If you use the Behringer UCA202 or other devices, you can list the name of the audio output (sinks) with: pacmd list-sinks | grep -e 'index:' -e device.string -e 'name:'

The audio inputs for the Behringer and other devices: pacmd list-sources | grep -e 'index:' -e device.string -e 'name:'

Download the shell script, livestream_with_jetson.sh, (try git clone https://github.com/NibbleHalfebyte/livestream_with_jetson.git in your home directory,) and make the script executable with chmod ug+x livestream_with_jetson.sh. Open the script in an text editor of your choice and search for the variable STREAM_KEY="<your_streaming_key>" and change <your_streaming_key> to the stream key of your Twitch account in the account settings. Next change the script variable LIVE_SERVER="<see_server_list_for_your_country>". Change <see_server_list_for_your_country> to a server for stream ingestion, see https://stream.twitch.tv/ingests/ for a list of Twitch servers. Enter the full path! You can use Facebook and YouTube servers, too.
To run the script open a xterminal window in the directory where you've downloaded the script and type ./livestream_with_jetson.sh and enter. Follow the dialog of the shell script.

The default input resolution is set with the variables SCREEN_WIDTH=1920, SCREEN_HEIGHT=1080 and limited to 30 fps at 1080p. With input resolution less or equal 1280x720 pixels you can set the INPUT_FRAMERATE=30 variable to INPUT_FRAMERATE=60 fps in the output stream. The screen size is cropped about 3.5% to the safe area of a TV and upscaled to 1920x1980 (HD). If you use 60 fps and 1280x720, change the DISPLAY_WIDTH=1920 and DISPLAY_HEIGHT=1080 shell script variable to DISPLAY_WIDTH=1280, DISPLAY_HEIGHT=720. Doing so is very important or you use the default 30 fps. You can change the output bitrate in the script from the default 4.5 mbit/s up to 6 mbit/s or set it lower.

(At the end of the gstreamer command is a comment for hard disk recording the stream parallel to the live stream. For an usb hard drive you'll need a 5 Volt greater 4 Ampere barrel jack power supply. The hard drive can consume up to 10 Watts when it starts spinning!)

Have fun!
