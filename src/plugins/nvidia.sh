#!/usr/bin/env bash

_PLUGIN_TITLE="Nvidia"
_PLUGIN_DESCRIPTION="Manage installation of proprietary Nvidia drivers"
_PLUGIN_OPTIONS=(
    "install;i;Install proprietary Nvidia drivers"
    "uninstall;;Uninstall proprietary Nvidia drivers"
    "force;f;Force usage even if no Nvidia GPUs are detected"
    "driver;;Select which driver to manage (default: latest)"
)
_PLUGIN_ROOT="true"

driver_packages=""
kernel_args="rd.driver.blacklist=nouveau --append=modprobe.blacklist=nouveau --append=nvidia-drm.modeset=1"
rpmfusion_nvidia_file="/etc/yum.repos.d/rpmfusion-nonfree-nvidia-driver.repo"
rpmfusion_nvidia_url="https://src.fedoraproject.org/rpms/fedora-workstation-repositories/raw/rawhide/f/rpmfusion-nonfree-nvidia-driver.repo"

function main() {
    [[ -z $driver ]] && driver="latest"
        
    case $driver in
        "latest")
            driver_packages="akmod-nvidia xorg-x11-drv-nvidia-cuda"
            ;;
        "470")
            driver_packages="akmod-nvidia-470xx xorg-x11-drv-nvidia-470xx-cuda"
            ;;
        "390")
            driver_packages="akmod-nvidia-390xx xorg-x11-drv-nvidia-390xx-cuda"
            ;;
        "340")
            driver_packages="akmod-nvidia-340xx xorg-x11-drv-nvidia-340xx-cuda"
            ;;
        *)
            die_message="Invalid --driver value, choose either:\n"
            die_message+=" - latest: current GeForce/Quadro/Tesla\n"
            die_message+=" - 470: legacy GeForce 600/700\n"
            die_message+=" - 390: legacy GeForce 400/500\n"
            die_message+=" - 340: legacy GeForce 8/9/200/300 (EOL)"

            die $die_message
            ;;
    esac

    if [[ $install == "true" ]]; then
        has_run="true"
        invoke_install
    fi
    
    if [[ $uninstall == "true" ]]; then
        has_run="true"
        invoke_uninstall
    fi
    
    if [[ $has_run != "true" ]]; then
        die "No option (--install/--uninstall) specified (see --help)"
    fi
}

function invoke_install() {
    check_nvidia_gpu

    if [[ ! -f $rpmfusion_nvidia_file ]]; then
        say "Downloading RPMFusion Nvidia repos..."
        curl $rpmfusion_nvidia_url --output $rpmfusion_nvidia_file

         if ! [ $? -eq 0 ]; then
            die "Unable to download RPMFusion Nvidia repo"
         fi
    fi

    say "Installing Nvidia drivers ($driver)..."
    rpm-ostree install $driver_packages

    if [ $? -eq 0 ]; then
        say "Setting kernel arguments..."
        rpm-ostree kargs --append-if-missing="$kernel_args"

        ask_reboot "Installation"
    else
        die "Installation failed"
    fi
}

function invoke_uninstall() {
    check_nvidia_gpu

    say "Uninstall Nvidia drivers ($driver)..."
    rpm-ostree uninstall $driver_packages

    if [ $? -eq 0 ]; then
        say "Unsetting kernel arguments..."
        rpm-ostree kargs --delete-if-present="$kernel_args"

        ask_reboot "Uninstallation"
    else
        die "Uninstallation failed"
    fi
}

function ask_reboot() {
    if [[ $(get_answer "$1 complete. Reboot now?") == "y" ]]; then
        say "Rebooting..."
        shutdown -r now
    else
        exit
    fi
}

function check_nvidia_gpu() {
    if [[ $force != "true" ]]; then
        if [[ ! -d /proc/driver/nvidia ]]; then
            die "No Nvidia GPU detected (use --force to override)"
        fi
    fi
}
