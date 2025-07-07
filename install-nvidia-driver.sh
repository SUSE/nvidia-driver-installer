#!/usr/bin/env bash

set -euo pipefail
source /host/etc/os-release
echo "Detected OS: $NAME ($PRETTY_NAME)"

INSTALLED_VERSION=$(chroot /host rpm -q nvidia-open-driver-G06-signed-kmp-default | sed -n 's/.*-\([0-9]\+\(\.[0-9]\+\)*\)_.*$/\1/p' || echo "")

if [[ "$ID" == "sles" ]]; then
    TARGET_VERSION="${SLES_DRIVER_VERSION:-570.144}"
    REGCODE="${SLESREGCODE:-no-reg-code}"
    REGEMAIL="${SLESREGEMAIL:-no-reg-email@example.com}"
elif [[ "$ID" == "sl-micro" ]]; then
    TARGET_VERSION="${SLEM_DRIVER_VERSION:-570.133.20}"
    REGCODE="${SLEMREGCODE:-no-reg-code}"
    REGEMAIL="${SLEMREGEMAIL:-no-reg-email@example.com}"
else
    echo "Unsupported OS type: $ID"; exit 1;
fi

echo "INSTALLED_VERSION: $INSTALLED_VERSION"
echo "TARGET_VERSION: $TARGET_VERSION"

if chroot /host which nvidia-smi > /dev/null 2>&1 && [[ "$INSTALLED_VERSION" == "$TARGET_VERSION" ]]; then
    echo "NVIDIA drivers already installed. Skipping installation."
else
    echo "nvidia-smi not found, not working or the target version not found. Proceeding with the drivers installation."

    if ! chroot /host test -f /etc/SUSEConnect; then
        echo "Registering system with SUSE..."
        chroot /host /usr/bin/SUSEConnect -r "$REGCODE" -e "$REGEMAIL" || {
        echo "ERROR: SUSEConnect registration failed"; exit 1; }
    fi

    if [[ "$ID" == "sles" ]]; then
        echo "Installing NVIDIA drivers on SLES..."
        chroot /host bash -c "
        set -euo pipefail
        # driver_version=\$(zypper se -s nvidia-open-driver | grep nvidia-open-driver- | sed 's/.* package \+| //g' | sed 's/\\s.*//g' | sort -rV | grep -v '^$' | head -n 1 | sed 's/[-_].*//g')
        driver_version=\"${SLES_DRIVER_VERSION}\"
        
        if ! zypper lr | grep -q 'nvidia-sle15sp6-main'; then
            zypper --non-interactive addrepo 'https://download.nvidia.com/suse/sle15sp6/' 'nvidia-sle15sp6-main'
        fi
        if ! zypper lr | grep -q 'nvidia-container-toolkit'; then
            zypper --non-interactive addrepo 'https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo'
        fi
        zypper --non-interactive --gpg-auto-import-keys refresh
        zypper remove -y --clean-deps nvidia-open-driver-G06-signed-kmp nvidia-compute-utils-G06 nvidia-container-toolkit || true
        zypper --non-interactive install -y --auto-agree-with-licenses \
            nvidia-open-driver-G06-signed-kmp=\"\$driver_version\" \
            nvidia-compute-utils-G06=\"\$driver_version\" \
            nvidia-container-toolkit
        touch /var/run/reboot-needed
        "
    elif [[ "$ID" == "sl-micro" ]]; then
        echo "Installing NVIDIA drivers on SL Micro..."
        chroot /host bash -c "
        set -euo pipefail
        # driver_version=\$(zypper se -s nvidia-open-driver | grep nvidia-open-driver- | sed 's/.* package \+| //g' | sed 's/\\s.*//g' | sort -V | grep -v '^$' | head -n 1 | sed 's/[-_].*//g')
        driver_version=\"${SLEM_DRIVER_VERSION}\"
        
        transactional-update shell <<EOF
        #!/bin/bash
        set -euo pipefail

        if ! zypper lr | grep -q 'nvidia-sle15sp6-main'; then
            zypper --non-interactive addrepo 'https://download.nvidia.com/suse/sle15sp6/' 'nvidia-sle15sp6-main'
        fi
        if ! zypper lr | grep -q 'nvidia-container-toolkit'; then
            zypper --non-interactive addrepo 'https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo'
        fi

        zypper --non-interactive --gpg-auto-import-keys refresh
        zypper remove -y --clean-deps nvidia-open-driver-G06-signed-kmp nvidia-compute-utils-G06 nvidia-container-toolkit || true
        zypper --non-interactive install --no-recommends -y --auto-agree-with-licenses \\
            nvidia-open-driver-G06-signed-kmp=\$driver_version \\
            nvidia-compute-utils-G06=\$driver_version \\
            nvidia-container-toolkit

        touch /var/run/reboot-needed
        exit
        EOF
        "
    fi
    echo "NVIDIA driver installation and reboot flag setup complete."
fi

echo "Pod idling." && tail -f /dev/null
