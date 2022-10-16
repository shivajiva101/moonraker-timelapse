#!/bin/sh
# Moonraker Timelapse component installer
#
# Copyright (C) 2021 Christoph Frei <fryakatkop@gmail.com>
# Copyright (C) 2021 Stephan Wendel aka KwadFan <me@stephanwe.de>
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Note:
# this installer script is heavily inspired by 
# https://github.com/protoloft/klipper_z_calibration/blob/master/install.sh

# Prevent running as root.
if [ ${UID} == 0 ]; then
    echo -e "DO NOT RUN THIS SCRIPT AS 'root' !"
    echo -e "If 'root' privileges needed, you will prompted for sudo password."
    exit 1
fi

# Force script to exit if an error occurs
set -e

# Find SRCDIR from the pathname of this script
SRCDIR="$(dirname "$(readlink -f "$0")")"

# Default Parameters
MOONRAKER_TARGET_DIR="${HOME}/moonraker/moonraker/components"
SYSTEMDDIR="/etc/init.d"
KLIPPER_CONFIG_DIR="${HOME}/printer_data/config"
FFMPEG_BIN="/usr/bin/ffmpeg"

# Define text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function stop_klipper {
    if [ "$(ls /etc/init.d | grep -F "klipper")" ]; then
        echo "Klipper service found! Stopping during Install."
        /etc/init.d/klipper stop
    else
        echo "Klipper service not found, please install Klipper first"
        exit 1
    fi
}

function stop_moonraker {
    if [ "$(ls /etc/init.d | grep -F "moonraker")" ]; then
        echo "Moonraker service found! Stopping during Install."
        /etc/init.d/moonraker stop
    else
        echo "Moonraker service not found, please install Moonraker first"
        exit 1
    fi
}

function link_extension {
    if [ -d "${MOONRAKER_TARGET_DIR}" ]; then
        echo "Linking extension to moonraker..."
        ln -sf "${SRCDIR}/component/timelapse.py" "${MOONRAKER_TARGET_DIR}/timelapse.py"
    else
        echo -e "ERROR: ${MOONRAKER_TARGET_DIR} not found."
        echo -e "Please Install moonraker first!\nExiting..."
        exit 1
    fi
    if [ -d "${KLIPPER_CONFIG_DIR}" ]; then
        echo "Linking macro file..."
        ln -sf "${SRCDIR}/klipper_macro/timelapse.cfg" "${KLIPPER_CONFIG_DIR}/timelapse.cfg"
    else
        echo -e "ERROR: ${KLIPPER_CONFIG_DIR} not found."
        echo -e "Try:\nUsage: ${0} -c /path/to/klipper_config\nExiting..."
        exit 1
    fi
}

function install_script {
# Create systemd service file
    SERVICE_FILE="${SYSTEMDDIR}/timelapse"
    #[ -f $SERVICE_FILE ] && return
    if [ -f $SERVICE_FILE ]; then
        # Force remove
        rm -f "$SERVICE_FILE"
    fi

    echo "Installing system start script..."
    /bin/sh -c "cat > ${SERVICE_FILE}" << EOF
#!/bin/sh /etc/rc.common
# Put this inside /etc/init.d/
# Dummy service or moonraker's update_manager

START=91
STOP=10
USE_PROCD=1


start_service() {
    procd_open_instance
    procd_set_param command /bin/sh -c "sleep 1; echo 'Restarting Klipper and Moonraker...'"
    #procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    /etc/init.d/klipper restart && /etc/init.d/moonraker restart
}
EOF
# Use systemctl to enable the systemd service script
    chmod +x /etc/init.d/timelapse
    /etc/init.d/timelapse enable
}


function restart_services {
    echo "Restarting Moonraker..."
    /etc/init.d/moonraker restart
    echo "Restarting Klipper..."
    /etc/init.d/klipper restart
}


function check_ffmpeg {

    if [ ! -f "$FFMPEG_BIN" ]; then
        echo -e "${YELLOW}WARNING:${NC} FFMPEG not found in '${FFMPEG_BIN}'. Render will not be possible!\nPlease install FFMPEG running:\n\n  sudo apt install ffmpeg\n\nor specify 'ffmpeg_binary_path' in moonraker.conf in the [timelapse] section if ffmpeg is installed in a different directory, to use render functionality"
	fi

}


### MAIN

# Parse command line arguments
while getopts "c:h" arg; do
    if [ -n "${arg}" ]; then
        case $arg in
            c)
                KLIPPER_CONFIG_DIR=$OPTARG
                break
            ;;
            [?]|h)
                echo -e "\nUsage: ${0} -c /path/to/klipper_config"
                exit 1
            ;;
        esac
    fi
    break
done

# Run steps
stop_klipper
stop_moonraker
link_extension
install_script
restart_services
check_ffmpeg

# If something checks status of install
exit 0
