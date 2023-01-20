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
    printf -- '\e[0m[\e[1;94m?\e[0m] %b\n' "${*}"
}

printTick() {
    printf -- '[\e[1;32m✓\e[0m] \e[1;32m%b\e[0m\n' "${*}"
}

# Print an error message on invalid input
invalidArgument() {
    printCross "Invalid argument!"
    exit 22
}

# Ask the user to pick the order in which the tracks will be played
askTrack() {
    printf -- "Track name      : %s\n" "${file##*/}"
    printf -- "Number %-8s : " "[1-$maxNum]"
    read -r num
}

# Ask the user to input the robot's IP address
askIP() {
    printf -- "    Robot IP : "
    read -r ip
}

# Determine if the provided IP is valid
# NOTE: An SSH server must be listening to this IP address
checkIP() {
    if nc -z -w 5 "$ip" 22 2>/dev/null; then
        printTick 'Robot SSH port open'
    else
        # Print a failure message and exit
        printCross 'The robot is unreachable. Make sure you are able to connect to it via SSH and try again!'
        exit 113 # No route to host
    fi
}

# Function that sorts the imported tracks
sortTracks() {
    # Ask the user to select a sorting method
    printQuestion 'How do you want to sort the files?'
    printf '    (1) Automatically\n    (2) Manually'
    read -r -s -n 1
    printf '\n\n'

    # Remove all previously created files (e.g. symlinks)
    rm -rf data/www/*

    # Sort tracks manually, according to user input
    if [[ $REPLY == [2] ]]; then
        # Count the number of files inside the music directory
        # shellcheck disable=SC2012
        maxNum=$(ls data/music/*.ogg | wc -l)

        # Loop over all files inside the music directory
        for file in data/music/*.ogg; do
            # Ask the user for input
            askTrack

            # Run until the given number is valid and create a symlink named after it
            until [[ "$num" -gt "0" && "$num" -le "$maxNum" ]] && ln -s ../../"$file" data/www/"$num" 2>/dev/null; do
                # Print an error if the number is invalid
                printf '\n'
                printCross 'Invalid input. Please try again!\n'

                # Ask the user again
                askTrack
            done
            printf '\n'
        done
    # Otherwise, sort tracks automatically
    else
        local i=1

        # Create a symlink for each file inside the directory
        for file in data/music/*.ogg; do
            ln -s ../../"$file" data/www/$i
            i=$(( i + 1 ))
        done
    fi
}

# Import tracks from a directory or online service
importTracks() {
    # Exit if ffmpeg is not installed
    if [[ ! $(command -v ffmpeg) ]]; then
        printCross 'ffmpeg is not installed!'
        exit 2
    fi

    # Ask the user to select an import method
    printQuestion 'Where would you like to import tracks from?'
    printf '    (1) From a directory\n    (2) From an online service (e.g. YouTube)'
    read -r -s -n 1
    printf '\n\n'

    if [[ $REPLY == [1] ]]; then
        printf -- '    Directory path : '
        read -r dirname

        # Convert each file to a format that the robot can play
        for file in "$dirname"/*; do
            ffmpeg -hide_banner -loglevel error -i "$file" -c:a libvorbis -vn -ar 48000 "data/music/${file##*/}.ogg"
        done
    elif [[ $REPLY == [2] ]]; then
        # Exit if yt-dlp is not installed
        if [[ ! $(command -v yt-dlp) ]]; then
            printCross 'yt-dlp is not installed!'
            exit 2
        fi

        # Ask the user to provide a URL
        printf -- '    Video or playlist URL : '
        read -r url

        # Download the file using yt-dlp and then convert it to vorbis, without keeping the original file
        yt-dlp -q --progress -o 'data/music/%(title)s.%(ext)s' -x --audio-format vorbis "$url"

        printf '\n'
    fi

    # Sort the tracks after an import has been completed
    sortTracks
}

# Show the order in which the tracks will be played
showTrackList() {
    local i=1

    printf -- '%s\n' \
    "+--------+--------------------------------+" \
    "| Number |           Track name           |" \
    "+--------+--------------------------------+" \

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

    # Print bottom row
    printf -- '+--------+--------------------------------+\n\n'
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

    # Choose a random port and check if it is being used by another process
    printInfo 'Searching for available port...'

    while nc -z 127.0.0.1 "$port" 2>/dev/null || [ -z "$port" ]; do
        port=$(( 1024 + RANDOM % 65535 ))
    done

    # Announce that a port has been found and we are ready to start
    printInfo "$port" 'is available!'

    # Start the web server
    printInfo 'Starting web server...'
    python3 -m http.server "$port" -d data/www 2>/dev/null 1>&2 &

    # Small delay to allow for the server to start
    # NOTE: Might not suffice for slower hardware
    sleep 0.3

    # Test the server
    if nc -z 127.0.0.1 "$port"; then
        printTick 'The server is running!\n'
    else
        printCross 'The server is unreachable. The cause of the issue could not be determined.'
        exit 113
    fi
}

# Connect to the robot via SSH and run the payload
sshConnect() {
    printInfo 'Please specify the robot IP.'

    # Check if git is installed
    if [[ $(command -v git) ]]; then
        # Provide a hint
        printInfo 'Tip: Leave the field empty for the last IP to be used.'

        # Ask the user for input
        askIP

        # Check if the variable is empty
        if [[ -z $ip ]]; then
            # Fetch the IP from the config file (if available)
            ip=$(git config -f data/.config network.ip)
            printf -- "\033[1A\033[15C%s\n" "$ip"

            # Check if the IP is valid (after autocompletion)
            checkIP
        # If the user has provided an IP, store it for future use
        else
            # Check if the IP is valid (before storing to config)
            checkIP

            # Store the IP in the config file
            git config -f data/.config network.ip "$ip"
        fi
    # If git is not installed, just ask the user for an IP each time the script is run
    else
        # Ask the user for input
        askIP

        # Check if the provided IP is valid
        checkIP
    fi

    # SSH into the robot and stop the music
    if [[ $1 == 'stop' ]]; then
        # Kill ogg123
        ssh "$ip" -l root 'pkill ogg123'

        # Print a success message
        printTick 'The music has been stopped.'
    # SSH into the robot and run the payload
    else
        # Run the listener script
        ssh "$ip" -l root 'sh -s' < play-music.sh "$(hostname -I | cut -d' ' -f1)":"$port"
    fi
}

# Use script's directory as root
cd "$(dirname "$0")" || exit

# Create the required directories
mkdir -p {data/music,data/www}

# Run only if an argument has been passed
if [[ -n $1 ]]; then
    # Check for arguments
    case "$1" in
        (--import|-i) importTracks    ;;
        (--sort|-s)   sortTracks      ;;
        (--stop|-p)   sshConnect stop ;;
        (*)           invalidArgument ;;
    esac

    exit 0
fi

# Check if the music directory is empty
if [[ -z "$(ls -A data/music)" ]]; then
    printInfo 'Music directory seems empty. Launching import wizard...'

    # Call the function for importing tracks
    importTracks
fi

# Initialize the web server
webserverInit

# Show the tracks in their respective order
showTrackList

# Connect to the robot over SSH and execute the payload
sshConnect
