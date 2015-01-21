#!/bin/bash
# 
# This script is intended to be called by transmission-daemon after a torrent 
# is finished. It analyzes the downloaded file and performs some operations 
# depending on the file type:
#
#   - zip files: they are decompressed and analyzed recursively
#   - video files: its english subtitles are automatically downloaded
#   
# You will need the following packages (install them with apt-get)
#
# dos2unix
# unzip
# wget
#
# Feel free to add support for other file formats
#

# Read the config file, which should be located in the same directory as this script
THIS=$(readlink -f $0)
SCRIPT=$(basename $THIS)
PWD=${THIS%/$SCRIPT}
CONF=$PWD/transmission-morning-after.conf
source $CONF

# Transmission sets these environment variables
# TR_APP_VERSION
# TR_TIME_LOCALTIME
# TR_TORRENT_DIR
# TR_TORRENT_HASH
# TR_TORRENT_ID
# TR_TORRENT_NAME

#
# analyze_video [path]
# downloads the english subtitles of [path]
#
function analyze_video() {
    filename=$(basename $1)
    dest="${1%.*}.srt"
    if [ -f "$dest" ]; then
        echo "Seems it already has subtitles; skipping"
    else
        temp="/tmp/kk"
        wget "http://immense-wave-6488.herokuapp.com/?$filename" -O $temp
        dos2unix $temp
        echo "1" > "$dest"
        tail -n +2 $temp >> "$dest"
    fi
}

#
# analyze_zip [path]
# uncompress [path] into [path]_contents/ and analyzes the unzipped content recursively.
#
function analyze_zip() {
    zipfile="$1"
    echo "Analyzing zip $zipfile"
    newdir="${zipfile}_contents"
    mkdir -p "$newdir"
    unzip -d "$newdir" "$zipfile"
    analyze "$newdir"
}

#
# analyze_rar [path]
# uncompress [path] into [path]_contents/ and analyzes the unzipped content recursively.
#
function analyze_rar() {
    rarfile="$1"
    echo "Analyzing rar $rarfile"
    newdir="${rarfile}_contents"
    mkdir -p "$newdir"
    unrar x -o- -p- -y "$rarfile" "$newdir"
    analyze "$newdir"
}

#
# analyze [path]
#
function analyze()
{
    path="$1"
    find "$path" | while read f; do
        echo "f is $f"
        mime=$(file -bi "$f")
        echo "Analyzing $f is $mime"
        case "$mime" in
            audio/*)
                echo "Nothing to do with audio..."
                ;;
            video/*)
                analyze_video "$f"
                ;;
            application/zip*)
                analyze_zip "$f"
                ;;
            application/x-rar*)
                analyze_rar "$f"
                ;;
            *)
                echo "Skipping..."
                ;;
        esac
    done
}

#
# Start analysis in the path given by Transmission.
#
analyze "$DOWNLOADS/$TR_TORRENT_NAME"

#
# Remove the torrent after SEEDING seconds
#
sleep $SEEDING && transmission-remote -n $TR_USER:$TR_PASS -t $TR_TORRENT_ID -r &

#
# Tell Zoe to notify us of the downloaded torrent
#
echo -n "dst=broadcast&tag=send&to=admin&msg=Torrent '$TR_TORRENT_NAME' finished" | nc localhost 30000

