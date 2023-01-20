# Music streaming for Dreame robot vacuums

## What is this?

vacuum-music is a pair of scripts that enable your vacuum robot to play music! All you have to do is pick the right song!

## How does it work?

There exist two scripts:
- `play-music` runs on your robot and acts as a middleman between it and your computer, allowing you to stream music.
- `send-music` runs on your PC and spins up a temporary web server, which provides the music files.

## Supported OSs

The main script is written in Bash, thus **only GNU/Linux** (and probably WSL) is supported. It would require a complete rewrite for cross-platform support to be added.

## First setup & Dependencies

Before using the scripts, make sure that your vacuum robot is reachable via SSH on the default port (22), the SSH keys on your computer are stored in ~/.ssh and you are able to connect without specifying a login password.

Then, proceed to install the following packages from your distribution's repositories:

**NOTE:** It is recommended that you install **all** the packages listed below.

<table>
    <th>Package name</th>
    <th>Features gained</th>
    <th>Required</th>
    <tr>
        <td>ffmpeg</td>
        <td>Track import</td>
        <td>✔️</td>
    </tr>
    <tr>
        <td>python3</td>
        <td>Web server</td>
        <td>✔️</td>
    </tr>
    <tr>
        <td>git</td>
        <td>Persistent settings</td>
        <td>❌</td>
    </tr>
    <tr>
        <td>yt-dlp</td>
        <td>Online music downloading</td>
        <td>❌</td>
    </tr>
</table>

## Available commands

<table>
    <tr>
        <td><code>-i, --import</code></td>
        <td>Launch the track import wizard</td>
    </tr>
    <tr>
        <td><code>-s, --sort</code></td>
        <td>Reorder tracks</td>
    </tr>
</table>