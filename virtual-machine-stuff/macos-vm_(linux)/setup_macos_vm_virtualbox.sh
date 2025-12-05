#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# --------------------------------------------------------------
# VirtualBox VM selector + configuration script
# --------------------------------------------------------------
# Detects the host distro, offers to install the required
# packages (dialog + virtualbox), lets the user pick a VM via an
# ncurses menu and then applies the desired VBoxManage settings.
# --------------------------------------------------------------

# ------------------- Helper functions -------------------------

die() {
    echo "Error: $1" >&2
    exit 1
}

install_packages() {
    local pkgs=("$@")
    case "$DISTRO" in
        ubuntu|debian)
            sudo apt-get update && sudo apt-get install -y "${pkgs[@]}" ;;
        fedora)
            sudo dnf install -y "${pkgs[@]}" ;;
        arch)
            sudo pacman -Sy --noconfirm "${pkgs[@]}" ;;
        *)
            die "Unsupported distro: $DISTRO" ;;
    esac
}

# ------------------- Detect distro ---------------------------

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO=${ID,,}
else
    die "Cannot determine Linux distribution."
fi

# ------------------- Check for required tools --------------

REQUIRED=("dialog" "VBoxManage")
MISSING=()

for cmd in "${REQUIRED[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING+=("$cmd")
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "The following required tools are missing: ${MISSING[*]}"
    read -rp "Do you want to install them now? [Y/n] " resp
    resp=${resp:-Y}
    if [[ $resp =~ ^[Yy]$ ]]; then
        case "$DISTRO" in
            ubuntu|debian) PKGS=("dialog") ;;
            fedora)        PKGS=("dialog") ;;
            arch)          PKGS=("dialog") ;;
        esac
        install_packages "${PKGS[@]}" || die "Package installation failed."
    else
        die "Cannot continue without the required tools."
    fi
fi

# ------------------- Build VM menu ---------------------------

mapfile -t VM_LINES < <(VBoxManage list vms 2>/dev/null)
[[ ${#VM_LINES[@]} -gt 0 ]] || die "No VirtualBox VMs found on this system."

MENU_ITEMS=()
for line in "${VM_LINES[@]}"; do
    # Expected format: "VM name" {uuid}
    if [[ $line =~ ^\"([^\"]+)\"[[:space:]]+\{([^\}]+)\}$ ]]; then
        vm_name="${BASH_REMATCH[1]}"
        vm_uuid="${BASH_REMATCH[2]}"
        MENU_ITEMS+=("$vm_name" "$vm_uuid")
    fi
done

# ------------------- Show ncurses menu -----------------------

CHOICE=$(dialog --clear \
                --backtitle "VirtualBox VM selector" \
                --title "Select a VM" \
                --menu "Choose the VM you want to configure:" 15 60 10 \
                "${MENU_ITEMS[@]}" \
                2>&1 >/dev/tty)

exit_status=$?
clear
[[ $exit_status -ne 0 ]] && die "No VM selected."

VM_NAME="$CHOICE"

# ------------------- Apply configuration ---------------------

echo "Applying settings to VM \"$VM_NAME\"..."

VBoxManage modifyvm "$VM_NAME" --cpu-profile "Intel Core i7-6700K"

VBoxManage modifyvm "$VM_NAME" \
    --cpuid-set 00000001 000106e5 00100800 0098e3fd bfebfbff

VBoxManage setextradata "$VM_NAME" \
    "VBoxInternal/Devices/efi/0/Config/DmiSystemProduct" "MacBookPro15,1"

VBoxManage setextradata "$VM_NAME" \
    "VBoxInternal/Devices/efi/0/Config/DmiSystemVersion" "1.0"

VBoxManage setextradata "$VM_NAME" \
    "VBoxInternal/Devices/efi/0/Config/DmiBoardProduct" "Mac-551B86E5744E2388"

VBoxManage setextradata "$VM_NAME" \
    "VBoxInternal/Devices/smc/0/Config/DeviceKey" \
    "ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"

VBoxManage setextradata "$VM_NAME" \
    "VBoxInternal/Devices/smc/0/Config/GetKeyFromRealSMC" 1

VBoxManage setextradata "$VM_NAME" \
    "VBoxInternal/TM/TSCMode" "RealTSCOffset"

echo "All settings applied successfully."

