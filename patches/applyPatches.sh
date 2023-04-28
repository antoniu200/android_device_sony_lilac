#!/usr/bin/env bash

# Apply all patches in this directory.
# Each patch must start with `# PWD: <rel path>`
# where `<rel path>` is the relative path from the android root dir,
# i.e. what would be `$ANDROID_BUILD_TOP`, to the path where the patch should be applied

set -euo pipefail

GREEN='\033[0;32m'
LGREEN='\033[1;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
PATCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function showError {
    echo -e "${RED}ERROR: $@${NC}" && false
}

repo_root=$(readlink -f "$PATCH_ROOT/../../../..")
if [ ! -d "$repo_root/device/sony/lilac/patches" ]; then
  showError "Failed to find repository root at $repo_root"
fi

numApplied=0
numSkipped=0
numWarned=0

function applyPatch {
    patch=${1:?"No patch specified"}

    patch_dir=$(head -n1 "$patch" | grep "# PWD: " | awk '{print $NF}')
    if [[ "$patch_dir" == "" ]]; then
        showError "Faulty patch: $patch"
    fi

    parent="$(basename "$(dirname "$patch")")"
    msg="$(basename "$patch")"
    if [[ "$parent" =~ asb-* ]]; then
        msg+=" - ${YELLOW}${parent^^}${NC}"
    fi
    echo -en "Applying $msg in ${patch_dir}: "
    if [[ $(wc -l < "$patch") == 1 ]]; then
        echo -e "${LGREEN}Skipped (empty).${NC}"
        ((++numSkipped))
    else
        patch_dir="$repo_root/$patch_dir"
        # If the reverse patch could be applied, then the patch was likely already applied
        patch --reverse --force  -p1 -d "$patch_dir" --input "$patch" --dry-run > /dev/null && applied=1 || applied=0
        if out=$(patch --forward -p1 -d "$patch_dir" --input "$patch" -r /dev/null --no-backup-if-mismatch 2>&1); then
            echo -e "${LGREEN}Done.${NC}"
            ((++numApplied))
            # We applied the patch but could apply the reverse before, i.e. would detect it as already applied.
            # This may happen for patches only deleting stuff where the reverse (adding it) may succeed via fuzzy match
            if [[ $applied == 1 ]]; then
                echo -e "${YELLOW}WARNING${NC}: Skip detection will not work correctly for this patch!"
                ((++numWarned))
            fi
        elif [[ $applied == 1 ]]; then
            echo -e "${GREEN}Skipped.${NC}"
            ((++numSkipped))
        else
            echo -e "${RED}Failed!${NC}"
            echo "$out"
            exit 1
        fi
    fi
}

# Apply the latest ASB patch for each project/folder
for filename in $(find "$PATCH_ROOT/asb-"* -maxdepth 1 -type f -name '*.patch' -printf "%f\n" | sort -u); do
    patch=$(find "$PATCH_ROOT/asb-"* -maxdepth 1 -type f -name "$filename" | sort | tail -n1)
    applyPatch "$patch"
done

# Apply custom patches
for p in "$PATCH_ROOT/"*.patch; do
    applyPatch "$p"
done

echo -e "Patching done! ${LGREEN}Applied: ${numApplied}${NC}, ${GREEN}skipped: ${numSkipped}${NC}, ${YELLOW}warnings: ${numWarned}${NC}"
