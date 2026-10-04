#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=lilac
VENDOR=sony

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

LILAC_DCM=false

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        -d | --dcm )
                LILAC_DCM=true
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

filter_proprietary_file() {
    local input="$1"
    local output="$2"

    awk -v lilac_dcm="${LILAC_DCM}" '
        BEGIN {
            depth = 0
            active[0] = 1
        }

        /^[[:space:]]*#[[:space:]]*@if[[:space:]]+LILAC_DCM[[:space:]]*$/ {
            depth++

            parent[depth] = active[depth - 1]
            condition[depth] = (lilac_dcm == "true")
            seen_else[depth] = 0

            active[depth] = parent[depth] && condition[depth]
            next
        }

        /^[[:space:]]*#[[:space:]]*@else[[:space:]]*$/ {
            if (depth == 0) {
                print FILENAME ":" NR ": @else without @if" > "/dev/stderr"
                exit 1
            }

            if (seen_else[depth]) {
                print FILENAME ":" NR ": duplicate @else" > "/dev/stderr"
                exit 1
            }

            seen_else[depth] = 1
            active[depth] = parent[depth] && !condition[depth]
            next
        }

        /^[[:space:]]*#[[:space:]]*@endif[[:space:]]*$/ {
            if (depth == 0) {
                print FILENAME ":" NR ": @endif without @if" > "/dev/stderr"
                exit 1
            }

            depth--
            next
        }

        active[depth] {
            print
        }

        END {
            if (depth != 0) {
                print FILENAME ": unterminated @if" > "/dev/stderr"
                exit 1
            }
        }
    ' "${input}" > "${output}"
}


# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PROPRIETARY_FILES="${TMP_DIR}/proprietary-files.txt"
PROPRIETARY_FILES_VENDOR="${TMP_DIR}/proprietary-files-vendor.txt"

filter_proprietary_file \
    "${MY_DIR}/proprietary-files.txt" \
    "${PROPRIETARY_FILES}"

filter_proprietary_file \
    "${MY_DIR}/proprietary-files-vendor.txt" \
    "${PROPRIETARY_FILES_VENDOR}"

extract "${PROPRIETARY_FILES}" "${SRC}" "${KANG}" --section "${SECTION}"
extract "${PROPRIETARY_FILES_VENDOR}" "${SRC}" "${KANG}" --section "${SECTION}"

#
# Blobs fixup start
#

DEVICE_ROOT="${ANDROID_ROOT}"/vendor/"${VENDOR}"/"${DEVICE}"/proprietary

# Add a restorecon for /persist/wlan to taimport_vendor.rc
sed -i '4 a\    restorecon /persist/wlan' "${DEVICE_ROOT}"/vendor/etc/init/taimport_vendor.rc

#
# Blobs fixup end
#

# Generate makefiles from the same filtered lists used for extraction
write_headers

write_makefiles "${PROPRIETARY_FILES}" true
write_makefiles "${PROPRIETARY_FILES_VENDOR}" true

write_footers

# --- Post-process Android.bp ---
ANDROIDBP="${ANDROIDBP:-${MY_DIR:-$PWD}/Android.bp}"
[ -f "$ANDROIDBP" ] || { echo "Android.bp not found at $ANDROIDBP" >&2; exit 1; }

awk '
  BEGIN { inblk=0; depth=0; name=""; buf="" }
  /^[ \t]*(android_app_import|dex_import|java_import)[ \t]*\{[ \t]*$/ && !inblk {
    inblk=1; depth=1; name=""; buf=$0 ORS; next
  }
  inblk {
    buf = buf $0 ORS
    if (name=="" && $0 ~ /name:[ \t]*"[^"]+"/) { match($0,/name:[ \t]*"([^"]+)"/,m); name=m[1] }
    o=gsub(/\{/, "", $0); c=gsub(/\}/, "", $0); depth += o - c
    if (depth==0) {
      if (!(name=="SemcCameraUI-xxhdpi-release" || name=="com.sonymobile.camera.addon.api")) {
        printf "%s", buf
      }
      inblk=0; name=""; buf=""
    }
    next
  }
  { print }
' "$ANDROIDBP" > "$ANDROIDBP.tmp" && mv "$ANDROIDBP.tmp" "$ANDROIDBP"

cat >>"$ANDROIDBP" <<'EOF'

android_app_import {
	name: "SemcCameraUI-xxhdpi-release",
	owner: "sony",
	apk: "proprietary/priv-app/SemcCameraUI-xxhdpi-release/SemcCameraUI-xxhdpi-release.apk",
	certificate: "platform",
	dex_preopt: {
		enabled: false,
	},
	privileged: true,
	uses_libs: ["com.sonymobile.camera.addon.api"],
}

java_import {
	name: "com.sonymobile.camera.addon.api",
	owner: "sony",
	jars: ["proprietary/framework/com.sonymobile.camera.addon.api.jar"],
	installable: true,
}
EOF
# --- End rewrite ---
