#!/bin/bash

# Help function
function help_message () {
    cat << EOF
    Possible uses:
    Arkivr --compress <directory> <-- Runs Arkivr in a given entrypoint
    Arkivr --formats   <-- List formats that will be compressed
    Arkivr --help      <-- Shows this help message
EOF
}

# CONSTANTS
multimedia_video=("m4v" "mov" "mp4")
multimedia_images=("jpg")
unstable_multimedia_images=("png") # PNG to AVIF conversion using FFMPEG generates severe artifacts, and intermediate conversion to lossless JPG is required
multimedia_audio=("m4a")

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
            HandBrakeCLI -e x265 --x265-preset medium -q 25 --crop 0:0:0:0 --aencoder opus -f av_mkv -i "$file" -o "$file.mkv"
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
        if [[ "${multimedia_audio[*]}" =~ "${extension,,}" ]]; then
            counter=$(($counter + 1))
            # echo -e "'\033[0;34m'Processing file $counter / $(($counter_pictures + $counter_videos)) -- $(($counter * 100 / $(($counter_pictures + $counter_videos))))% '\e[0m'"
            echo "Compressing audio: $file"
            ffmpeg -i "$file" "$file.opus"
            if [[ $? == 0 ]]; then
                echo "No errors reported: deleting original and temporary artifact"
                rm "$file"
            else
                echo "Exit code is not 0: deleting artifact"
                rm "$file.opus"
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


main () {
    echo "Arkivr v1"
    verify_environment
    case $1 in
        "--help")
            help_message
            ;;
        "--formats")
            supported_formats
            ;;
        "--compress")
            compress "$2"
            ;;
    esac
}

main $1 "$2"