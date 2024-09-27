#!/bin/sh

set -e
sudo true
export PATH="/usr/sbin:/sbin:$PATH"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-8}"
SWAP_SIZE_SECTORS="$((SWAP_SIZE_GB * 1024 * 1024 * 2))"
echo "Checking current partition layout..."
CURRENT_LAYOUT="$(sudo sfdisk -d /dev/sda)"
for tool in sfdisk fdisk resize2fs partprobe; do
    if ! command -v $tool >/dev/null 2>&1; then
        echo "Installing $tool..."
        if command -v apt-get >/dev/null 2>&1; then
            case $tool in
                sfdisk)
                    sudo apt-get update && sudo apt-get install -y util-linux
                    ;;
                partprobe)
                    sudo apt-get update && sudo apt-get install -y parted
                    ;;
                resize2fs)
                    sudo apt-get update && sudo apt-get install -y e2fsprogs
                    ;;
                *)
                    sudo apt-get update && sudo apt-get install -y $tool
                    ;;
            esac
        else
            echo "Error: This script only supports Debian-based systems." >&2
            exit 1
        fi
    fi
done
for tool in sfdisk fdisk resize2fs partprobe; do
    if ! command -v $tool >/dev/null 2>&1; then
        echo "Error: $tool is still not available after installation attempt." >&2
        exit 1
    fi
done
if ! echo "$CURRENT_LAYOUT" | grep -q '/dev/sda1'; then
  echo "Error: /dev/sda1 not found. Unexpected partition layout." 1>&2
  exit 1
fi
if ! echo "$CURRENT_LAYOUT" | grep -q '/dev/sda2'; then
  echo "Error: /dev/sda2 (extended partition) not found. Unexpected partition layout." 1>&2
  exit 1
fi
if ! echo "$CURRENT_LAYOUT" | grep -q '/dev/sda5'; then
  echo "Error: /dev/sda5 (swap partition) not found. Unexpected partition layout." 1>&2
  exit 1
fi
echo "Partition layout recognized. Proceeding with changes..."
echo "Turning off any active swap partitions..."
sudo swapoff -a
echo "Deleting the extended and swap partitions..."
(
echo d      # Delete partition
echo 5      # Logical swap partition
echo d      # Delete partition
echo 2      # Extended partition
echo w      # Write changes
) | sudo fdisk /dev/sda
if [ "$?" != "0" ]; then
  echo "Error: Partition deletion failed." 1>&2
  exit 1
fi
sudo partprobe /dev/sda
TOTAL_SECTORS="$(sudo blockdev --getsz /dev/sda)"
NEW_SIZE="$((TOTAL_SECTORS - SWAP_SIZE_SECTORS - 2048))"
echo "Resizing /dev/sda1 to take up all space except the last $SWAP_SIZE_GB GB..."
(
echo d          # Delete partition
echo n          # Create a new partition
echo p          # Primary partition
echo 1          # Partition number 1
echo 2048       # Start sector (same as before)
echo $NEW_SIZE  # End sector (calculated to take all space except the last SWAP_SIZE_GB)
echo w          # Write changes
) | sudo fdisk /dev/sda
if [ "$?" != "0" ]; then
  echo "Error: Failed to resize /dev/sda1." 1>&2
  exit 1
fi
sudo partprobe /dev/sda
echo "Resizing filesystem on /dev/sda1..."
sudo resize2fs /dev/sda1
echo "Creating new swap partition in the last $SWAP_SIZE_GB GB..."
(
echo n                   # New partition
echo e                   # Extended partition
echo                     # Default partition number (should be 2)
echo $(($NEW_SIZE + 1))  # Start sector (right after /dev/sda1)
echo                     # Accept default (end of the disk)
echo n                   # New logical partition
echo                     # Default partition number (should be 5)
echo                     # Default start sector
echo                     # Default end sector (use full remaining space)
echo t                   # Change partition type
echo 5                   # Logical partition
echo 82                  # Linux swap
echo w                   # Write changes
) | sudo fdisk /dev/sda
if [ "$?" != "0" ]; then
  echo "Error: Failed to create swap partition." 1>&2
  exit 1
fi
sudo partprobe /dev/sda
echo "Formatting the new swap partition..."
sudo mkswap /dev/sda5
echo "Enabling the new swap partition..."
sudo swapon /dev/sda5
echo "Partition resizing complete. A reboot is required for changes to take effect."
