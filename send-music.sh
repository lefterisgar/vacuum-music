#!/bin/bash

# Perform cleanup operations on exit (e.g. stopping the web server)
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

# Initialize the web server
webserverInit() {
    # Check if python3 is installed
    printInfo 'Checking Python version...'

    if [[ $(command -v python3) ]]; then
        printTick "$(python3 -V)"
    else
        printCross 'Python 3 is not installed!'
        exit 2
    fi

    # Remove all previously created files (e.g. symlinks)
    rm -rf data/www/*

    # Choose a random port and check if it is being used by another process
    printInfo 'Searching for available port...'

    while nc -z 127.0.0.1 "$port" 2>/dev/null || [ -z "$port" ]; do
        port=$(( 1024 + RANDOM % 65535 ))
    done

    # Announce that a port has been found and we are ready to start
    printInfo "$port" 'is available!'

    # Start the web server
    printInfo 'Starting web server...'
    python3 -m http.server $port -d data/www 2>/dev/null 1>&2 &

    # Small delay to allow for the server to start
    # NOTE: Might not suffice for slower hardware
    sleep 0.3

    # Test the server
    if nc -z 127.0.0.1 "$port"; then
        printTick 'The server is running!'
    else
        printCross 'The server is unreachable. The cause of the issue could not be determined.'
        exit 113
    fi
}

# Connect to the robot via SSH and run the payload
sshConnect() { ssh 192.168.1.7 -l root 'sh -s' < play-music.sh "$(hostname -I | cut -d' ' -f1)":"$port"; }

# Ask the user to pick the order in which the tracks will be played
askTrack() {
    printf -- "Track name      : %s\n" "${file##*/}"
    printf -- "Number %-8s : " "[1-$maxNum]"
    read num
}

# Show the order in which the tracks will be played
showTrackList() {
    local i=1

    printf -- '+--------+--------------------------------+\n'
    printf -- '| Number |           Track name           |\n'
    printf -- '+--------+--------------------------------+\n'

    # Loop over all symlinks and print their target as well as their order
    for file in data/www/*; do
        # Find symlink target
        symlink=$(readlink "$file")

        # Remove the path
        symlink=${symlink##*/}

        # Make sure the filename isn't too big
        symlink=${symlink:0:30}

        # Print number & track name
        printf -- "| %-7s|%31s |\n" "$i" "$symlink"
        i=$(( i + 1 ))
    done
    printf -- '+--------+--------------------------------+\n'
}

# Use script's directory as root
cd "$(dirname "$0")" || exit

# Create a data directory
mkdir -p data

# Initialize the web server
webserverInit

i=1

# Ask the user to select a sorting method
printQuestion 'How do you want to sort the files?\n'
printf '    (1) Automatically\n    (2) Manually'
read -s -n 1
printf '\n\n'

if [[ $REPLY == [2] ]]; then
    # Count the number of files inside the music directory
    maxNum=$(ls data/music | wc -l)

    # Loop over all files inside the music directory
    for file in data/music/*; do
        # Ask the user for input
        askTrack

        # Run until the given number is valid and create a symlink named after it
        until [[ "$num" -gt "0" ]] && [[ "$num" -le "$maxNum" ]] && ln -s ../../"$file" data/www/"$num" 2>/dev/null; do
            # Print an error if the number is invalid
            printf '\n'
            printCross 'Invalid input. Please try again!\n'

            # Ask the user again
            askTrack
        done
        printf '\n'
    done
else
    # Create a symlink for each file inside the directory
    for file in data/music/*; do
        ln -s ../../"$file" data/www/$i
        i=$(( i + 1 ))
    done
fi

# Show the tracks in their respective order
showTrackList

# Connect to the robot over SSH and execute the payload
sshConnect
