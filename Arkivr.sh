#!/bin/bash

# Help function
function help_message () {
    cat << EOF
    Possible uses:
    Arkivr --compress <directory> <-- Runs Arkivr in a given entrypoint
    Arkivr --compress <directory> --handbrake-preset <path/to/config.json> <-- When Arkivr compresses a video, it uses the specified HandBrake config file
    Arkivr --formats   <-- List formats that will be compressed
    Arkivr --help      <-- Shows this help message

    Arguments:
    (arguments do not need to follow a specific order)

    --help | -h                         Displays this help message
    --formats | -f                      Shows supported formats
                                            Note: This list limits HandBrake in working only on files with these extensions
    --compress | -c  <directory>        Scan and compress files within the entrypoint directory
        --handbrake-preset|-p   <path>  Can be used with the --compress option to provide a config.json for HandBrake to use

EOF
}

# CONSTANTS
multimedia_video=("m4v" "mov" "mp4")
multimedia_images=("jpg")
unstable_multimedia_images=("png") # PNG to AVIF conversion using FFMPEG generates severe artifacts, and intermediate conversion to lossless JPG is required

function supported_formats () {
    cat << EOF
    Supported formats:
    Video files (Compressed using HandBrakeCLI / x265 CRF 25): ${multimedia_video[*]}
    Image files (Compressed using ffmpeg / AVIF CRF 25): ${multimedia_images[*]}
EOF
}

function compress () {
    # ARGUMENTS
    entrypoint=$1
    pushd "$entrypoint"
    tput init

    # Count pictures
    counter_pictures=0
    for iterator in ${multimedia_images[@]}; do
        pictures=$(find . -type f -name "*.$iterator" | wc -l)
        counter_pictures=$(($counter_pictures + $pictures))
    done
    echo "Total pictures: $counter_pictures"
    # Count videos
    counter_videos=0
    for iterator in ${multimedia_video[@]}; do
        videos=$(find . -type f -name "*.$iterator" | wc -l)
        counter_videos=$(($counter_videos + $videos))
    done
    echo "Total video: $counter_videos"
    echo "Total files to process: $(($counter_pictures + $counter_videos))"

    counter=0
    # Compress the files
    find . -type f | while read file; do
        extension="${file##*.}"
        if [[ "${multimedia_video[*]}" =~ "${extension,,}" ]]; then
            counter=$(($counter + 1))
            echo -e "'\033[0;34m'Processing file $counter / $(($counter_pictures + $counter_videos)) -- $(($counter * 100 / $(($counter_pictures + $counter_videos))))% '\e[0m'"
            echo "Compressing video: $file"
            if [ -z "${var_handbrake_preset+x}" ]; then
                echo "No config file specified, using default Arkivr settings"
                HandBrakeCLI -e x265 --x265-preset medium -q 25 --crop 0:0:0:0 --aencoder opus -f av_mkv -i "$file" -o "$file.mkv"
            else
                echo "Using given ${var_compression_entrypoint} config file"
                HandBrakeCLI --preset-import-file "${var_handbrake_preset}" -i "$file" -o "$file.mkv"
            fi
            if [[ $? == 0 ]]; then
                echo "No errors reported: deleting original"
                rm "$file"
            else
                echo "Exit code is not 0: deleting artifact"
                rm "$file.mkv"
            fi
        fi
        if [[ "${multimedia_images[*]}" =~ "${extension,,}" ]]; then
            counter=$(($counter + 1))
            echo -e "'\033[0;34m'Processing file $counter / $(($counter_pictures + $counter_videos)) -- $(($counter * 100 / $(($counter_pictures + $counter_videos))))% '\e[0m'"
            echo "Compressing image: $file"
            ffmpeg -i "$file" -crf 25 "$file.avif"
            if [[ $? == 0 ]]; then
                echo "No errors reported: deleting original"
                rm "$file"
            else
                echo "Exit code is not 0: deleting artifact"
                rm "$file.avif"
            fi
        fi
        if [[ "${unstable_multimedia_images[*]}" =~ "${extension,,}" ]]; then
            counter=$(($counter + 1))
            echo -e "'\033[0;34m'Processing file $counter / $(($counter_pictures + $counter_videos)) -- $(($counter * 100 / $(($counter_pictures + $counter_videos))))% '\e[0m'"
            echo "Compressing image: $file"
            ffmpeg -i "$file" -crf 0 "$file.jpg" # I honestly doubt that -crf 0 work here and makes it lossless.
            ffmpeg -i "$file" -crf 25 "$file.avif"
            if [[ $? == 0 ]]; then
                echo "No errors reported: deleting original and temporary artifact"
                rm "$file" "$file.jpg"
            else
                echo "Exit code is not 0: deleting artifact"
                rm "$file.avif" "$file.jpg"
            fi
        fi
    done

    popd
}

function verify_environment() {
    if hash HandBrakeCLI 2>/dev/null && hash ffmpeg 2>/dev/null; then
        return 0
    else
        cat << EOF
    ERROR: HandBrakeCLI or ffmpeg not found or have wrong aliases.
    To install HandBrake CLI check this link: https://handbrake.fr/downloads2.php
    To install ffmpeg check this link       : https://ffmpeg.org/download.html
    (consider using your package manager instead)
EOF
        return 1
    fi
}

echo "Arkivr v1.1"
verify_environment

# Check arguments
while [ ! -z "$1" ]; do
case "$1" in
    --help|-h)
        # shift
        echo "You asked for help"
        help_message
        ;;
    --formats|-f)
        shift
        supported_formats
        ;;
    --compress|-c)
        shift
        if [ ! -z "${1+x}" ]; then
            var_compression_entrypoint=$1
        else
            echo "Error: argument --compress and -c require an entrypoint path"
            exit 1
        fi
        ;;
    --handbrake-preset|-p)
        shift
        if [ ! -z "${1+x}" ]; then
            var_handbrake_preset=$(realpath "$1")
            echo "$var_handbrake_preset"
            if [ ! -f "$var_handbrake_preset" ]; then
                echo "Error: specified handbrake config file does not exist ($var_handbrake_preset)"
                exit 1
            fi
        else
            echo "Error: argument --handbrake-preset and -p require an HandBrake JSON config file path"
            exit 1
        fi
        ;;
    *)
        echo "Invalid argument: $1"
        help_message
        ;;

esac
shift
done

if [ ! -z "${var_compression_entrypoint+x}" ]; then
    compress "${var_compression_entrypoint}"
fi