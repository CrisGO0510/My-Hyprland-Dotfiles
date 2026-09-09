#!/usr/bin/env sh

# Set local configuration variables
confDir="$HOME/.config"
step=5

# El aviso de volumen/mute lo dibuja la barra: VolumeWidget.qml escucha a
# Pipewire y asoma su tooltip. Por eso aqui no se manda ninguna notificacion.

# Check if SwayNC is available, otherwise fall back to notify-send
use_swaync=false
if command -v swaync-client >/dev/null 2>&1; then
    use_swaync=true
fi

# Define functions

print_usage() {
    cat <<EOF
Usage: $(basename "$0") -[device] <action> [step]

Devices/Actions:
    -i    Input device
    -o    Output device
    -p    Player application
    -s    Select output device
    -t    Toggle to next output device

Actions:
    i     Increase volume
    d     Decrease volume
    m     Toggle mute

Optional:
    step  Volume change step (default: 5)

Examples:
    $(basename "$0") -o i 5     # Increase output volume by 5
    $(basename "$0") -i m       # Toggle input mute
    $(basename "$0") -p spotify d 10  # Decrease Spotify volume by 10 
    $(basename "$0") -p '' d 10  # Decrease volume by 10 for all players 

EOF
    exit 1
}

change_volume() {
    local action=$1
    local step=$2
    local device=$3
    local delta="-"

    [ "${action}" = "i" ] && delta="+"

    case $device in
        "pamixer")
            pamixer $srce -"$action" "$step"
            ;;
        "playerctl")
            playerctl --player="$srce" volume "$(awk -v step="$step" 'BEGIN {print step/100}')${delta}"
            ;;
    esac
}

toggle_mute() {
    local device=$1

    case $device in
        "pamixer")
            pamixer $srce -t
            ;;
        "playerctl")
            local volume_file="/tmp/$(basename "$0")_last_volume_${srce:-all}"
            if [ "$(playerctl --player="$srce" volume | awk '{ printf "%.2f", $0 }')" != "0.00" ]; then
                playerctl --player="$srce" volume | awk '{ printf "%.2f", $0 }' > "$volume_file"
                playerctl --player="$srce" volume 0
            else
                if [ -f "$volume_file" ]; then
                    last_volume=$(cat "$volume_file")
                    playerctl --player="$srce" volume "$last_volume"
                else
                    playerctl --player="$srce" volume 0.5
                fi
            fi
            ;;
    esac
}

select_output() {
    local selection=$1
    if [ -n "$selection" ]; then
        device=$(pactl list sinks | grep -C2 -F "Description: $selection" | grep Name | cut -d: -f2 | xargs)
        if pactl set-default-sink "$device"; then
            if $use_swaync; then
                swaync-client -n --body "Audio device switched" --summary "Activated: $selection" --app-name "volumecontrol"
            else
                notify-send -t 2000 -r 2 -u low "Activated: $selection"
            fi
        else
            if $use_swaync; then
                swaync-client -n --body "Failed to switch audio device" --summary "Error activating $selection" --app-name "volumecontrol" --urgency critical
            else
                notify-send -t 2000 -r 2 -u critical "Error activating $selection"
            fi
        fi
    else
        pactl list sinks | grep -ie "Description:" | awk -F ': ' '{print $2}' | sort
    fi
}

toggle_output() {
    local default_sink=$(pamixer --get-default-sink | awk -F '"' 'END{print $(NF - 1)}')
    mapfile -t sink_array < <(select_output)
    local current_index=$(printf '%s\n' "${sink_array[@]}" | grep -n "$default_sink" | cut -d: -f1)
    local next_index=$(( (current_index % ${#sink_array[@]}) + 1 ))
    local next_sink="${sink_array[next_index-1]}"
    select_output "$next_sink"
}

# Main script logic

# Parse options
while getopts "iop:st" opt; do
    case $opt in
        i)
            device="pamixer"
            srce="--default-source"
            ;;
        o)
            device="pamixer"
            srce=""
            ;;
        p)
            device="playerctl"
            srce="${OPTARG}"
            ;;
        s)
            select_output "$(select_output | rofi -dmenu -config "${confDir}/rofi/config.rasi")"
            exit
            ;;
        t)
            toggle_output
            exit
            ;;
        *)
            print_usage
            ;;
    esac
done

shift $((OPTIND-1))

# Check if device is set
[ -z "$device" ] && print_usage

# Execute action
case $1 in
    i|d) change_volume "$1" "${2:-$step}" "$device" ;;
    m) toggle_mute "$device" ;;
    *) print_usage ;;
esac
