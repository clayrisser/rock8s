#!/bin/sh

KUBESPRAY_DATA_DIR="${kubespray_data_dir}"
APT_LOCK_MAX_WAIT_TIME=600
APT_RETRY_INTERVAL=10
export DEBIAN_FRONTEND=noninteractive
is_lock_file_open() {
  sudo lsof -t "/var/lib/apt/lists/lock" >/dev/null 2>&1 ||
  sudo lsof -t "/var/lib/dpkg/lock-frontend" >/dev/null 2>&1 ||
  sudo lsof -t "/var/lib/dpkg/lock" >/dev/null 2>&1
}
wait_for_lock_release() {
  wait_time=0
  while is_lock_file_open; do
    if [ "$wait_time" -ge "$APT_LOCK_MAX_WAIT_TIME" ]; then
      echo "Timeout reached. Lock file is still present."
      exit 1
    fi
    echo "Waiting for apt lock file to be released..."
    sleep $APT_RETRY_INTERVAL
    wait_time=$((wait_time + $APT_RETRY_INTERVAL))
  done
}
wait_for_lock_release
if ! command -v docker &> /dev/null; then
    if ! curl -fsSL https://get.docker.com -o get-docker.sh; then
        echo "Error downloading Docker installation script. Exiting." >&2
        exit 1
    fi
    if ! sudo sh get-docker.sh; then
        echo "Error installing Docker. Exiting." >&2
        exit 1
    fi
    rm -f get-docker.sh
    sudo usermod -aG docker $USER
fi
mkdir -p "$KUBESPRAY_DATA_DIR"
rm -rf "$KUBESPRAY_DATA_DIR/*"
chmod 700 "$KUBESPRAY_DATA_DIR"
