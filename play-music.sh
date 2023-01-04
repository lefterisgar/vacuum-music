#!/bin/sh

# Fail fast check
if [ -z "$1" ]; then
    echo URL not specified!
    echo Usage: play-music [URL]
fi

i=1

# Check if the file to be played exists
while wget -q --spider http://"$1"/"$i"; do
    # Stream the audio file
    wget -qO- http://"$1"/"$i" | ogg123 -

    # Increment the counter so the next file will be played
    i=$(( i + 1 ))
done
