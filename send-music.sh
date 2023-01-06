#!/bin/bash

trap "exit" INT TERM
trap "kill 0" EXIT

# Functions for printing colored symbols to the console
printCross() {
    printf -- '[\e[1;31m✗\e[0m] \e[1;31m%b\e[0m\n' "${*}"
}

printInfo() {
    printf -- '[\e[1;93mi\e[0m] %b\n' "${*}"
}

printQuestion() {
    printf -- '\e[0m[\e[1;94m?\e[0m] %b' "${*}"
}

printTick() {
    printf -- '[\e[1;32m✓\e[0m] \e[1;32m%b\e[0m\n' "${*}"
}

webserverInit() {
    rm -r data/www/*
    printInfo 'Searching for available port...'

    while nc -z 127.0.0.1 "$port" 2>/dev/null || [ -z "$port" ]; do
        port=$(( 1024 + RANDOM % 65535 ))
    done

    printInfo "$port" 'is available!'

    printInfo 'Starting web server...'

    # Start the web server
    data/valetudo-helper-httpbridge-amd64 -p "$port" -d data/www >/dev/null &

    # Small delay to allow for the server to start
    sleep 0.8

    # Test the server
    if nc -z 127.0.0.1 "$port"; then
        printTick 'The server is running!'
    else
        printCross 'The server is unreachable. The cause of the issue could not be determined.'
        exit 113
    fi
}

sshConnect() { ssh 192.168.1.7 -l root 'sh -s' < play-music.sh "$(hostname -I | cut -d' ' -f1)":"$port"; }

askTrack() {
    printf -- "Track name        : %s\n" "${file##*/}"
    printf -- "Number %-10s : " "[1-$maxNum]"

    read num
}

showTrackList() {
    local i=1
    printf -- '+-------------------+-----------------+\n'
    printf -- '| Track name        |          Number |\n'
    printf -- '+-------------------+-----------------+\n'

    for file in data/www/*; do
        if [ -f $file ]; then
            symlink=$(readlink $file)
            printf -- "|%-19s|%17s|\n" "${symlink##*/}" "$i"
            i=$(( i + 1 ))
        fi
    done
    printf -- '+-------------------+-----------------+\n'
}

# Use script's directory as root
cd "$(dirname "$0")" || exit

# Create a data directory
mkdir -p data

if [ -f data/valetudo-helper-httpbridge-amd64 ]; then
    printTick "valetudo-helper-httpbridge $(data/valetudo-helper-httpbridge-amd64 -V)"
else
    printCross 'The required web server binary was not found!'

    # Ask the user if he wants to download it
    read -n 1 -r -p "$(printQuestion "Do you want to automatically download it? (y/n) ")"
    printf '\n'

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check if wget is present on the system
        if [[ $(command -v wget) ]]; then
            # Download the latest release from GitHub
            printInfo 'Downloading web server...'
            wget -q --show-progress -P data https://github.com/Hypfer/valetudo-helper-httpbridge/releases/latest/download/valetudo-helper-httpbridge-amd64

            # Make the file executable
            printInfo 'Making the file executable...'
            chmod +x data/valetudo-helper-httpbridge-amd64

            printTick 'Installation successful!'
        else
            printCross 'Wget is not installed! Can'\''t proceed.'
            exit 2
        fi
    else
        # Provide instructions for manual installation of the web server
        printInfo 'You can manually download it at: https://github.com/Hypfer/valetudo-helper-httpbridge/releases/latest.'
        printInfo 'Then place the executable under the data directory.'
        exit 2
    fi
fi

# Initialize the web server
webserverInit

i=1

# Ask the user to select sorting method
printQuestion 'How do you want to sort the files?\n'
printf '    (1) Automatically\n    (2) Manually'
read -s -n 1
printf '\n\n'

if [[ $REPLY == [2] ]]; then
    for file in data/music/*; do
        maxNum=$(ls data/music | wc -l)
        askTrack

        until [[ "$num" -gt "0" ]] && [[ "$num" -le "$maxNum" ]] && ln -s ../../"$file" data/www/"$num" 2>/dev/null; do
            printf '\n'
            printCross 'Invalid input. Please try again!\n'
            askTrack
        done
        printf '\n'
    done
    showTrackList
else
    # Create a symlink for each file inside the directory
    for file in data/music/*; do
        ln -s ../../"$file" data/www/$i
        i=$(( i + 1 ))
    done
    showTrackList
fi

# Connect to the robot over SSH and execute the payload
sshConnect
