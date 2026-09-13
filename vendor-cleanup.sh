#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$SCRIPT_DIR/../../../vendor/sony/lilac"
TREE="$VENDOR/proprietary"
GITIGNORE="$VENDOR/.gitignore"
FILES=(
    "$SCRIPT_DIR/proprietary-files-vendor.txt"
    "$SCRIPT_DIR/proprietary-files.txt"
)

for list in "${FILES[@]}"; do
    [ -f "$list" ] || { echo "Missing: $list" >&2; exit 1; }
done
[ -d "$TREE" ] || { echo "Missing proprietary tree: $TREE" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PINNED="$WORK/pinned"
PINNED_PATHS="$WORK/pinned-paths"
NON_PINNED="$WORK/non-pinned"

# Parse both proprietary lists. Destination paths are authoritative.
awk -v pinned="$PINNED" -v non_pinned="$NON_PINNED" '
    {
        sub(/\r$/, "")
    }
    /^[[:space:]]*(#|$)/ {
        next
    }
    {
        line = $0
        sub(/^-/, "", line)

        if (match(line, /\|[0-9a-fA-F]{40}$/)) {
            hash = substr(line, RSTART + 1, 40)
            pathspec = substr(line, 1, RSTART - 1)
            n = split(pathspec, path, ":")
            print path[n] "|" hash >> pinned
        } else {
            n = split(line, path, ":")
            print path[n] >> non_pinned
        }
    }
' "${FILES[@]}"

touch "$PINNED" "$NON_PINNED"
cut -d'|' -f1 "$PINNED" | sort -u > "$PINNED_PATHS"
sort -u -o "$NON_PINNED" "$NON_PINNED"

echo "Vendor tree: $VENDOR"
echo "Pinned files: $(wc -l < "$PINNED_PATHS")"
echo "Non-pinned files: $(wc -l < "$NON_PINNED")"

# Verify every pinned file before doing anything destructive.
while IFS='|' read -r file expected; do
    [ -n "$file" ] || continue
    source="$TREE/$file"

    if [ ! -f "$source" ]; then
        echo "Missing pinned file: $file" >&2
        exit 1
    fi

    actual=$(sha1sum "$source" | cut -d' ' -f1)

    if [ "$actual" != "$expected" ]; then
        echo
        echo "Hash mismatch: $file"
        echo "  expected: $expected"
        echo "  actual:   $actual"
        printf "Update the recorded SHA1? [y/N] "

        read -r answer </dev/tty
        case "$answer" in
            y|Y|yes|YES)
                updated=0

                for list in "${FILES[@]}"; do
                    awk -v file="$file" -v hash="$actual" '
                        {
                            sub(/\r$/, "")
                            original = $0
                            line = $0
                            sub(/^-/, "", line)

                            if (match(line, /\|[0-9a-fA-F]{40}$/)) {
                                pathspec = substr(line, 1, RSTART - 1)
                                n = split(pathspec, path, ":")

                                if (path[n] == file) {
                                    sub(/\|[0-9a-fA-F]{40}$/, "|" hash, original)
                                    changed = 1
                                }
                            }

                            print original
                        }
                        END {
                            if (changed)
                                exit 10
                        }
                    ' "$list" > "$list.tmp" && status=0 || status=$?

                    if [ "$status" -eq 10 ]; then
                        mv "$list.tmp" "$list"
                        updated=1
                    else
                        rm -f "$list.tmp"
                        [ "$status" -eq 0 ] || exit "$status"
                    fi
                done

                [ "$updated" -eq 1 ] || {
                    echo "Could not find pinned entry for: $file" >&2
                    exit 1
                }

                echo "Updated SHA1: $file"
                ;;
            *)
                echo "Aborted."
                exit 1
                ;;
        esac
    fi
done < "$PINNED"

echo "All pinned files verified."

# Delete every non-directory entry that is not pinned.
deleted=0
while IFS= read -r -d '' path; do
    rel="${path#"$TREE"/}"

    if ! grep -Fxq -- "$rel" "$PINNED_PATHS"; then
        rm -rf -- "$path"
        ((deleted += 1))
    fi
done < <(find "$TREE" -mindepth 1 ! -type d -print0)

# Remove empty directories left behind by the cleanup.
find "$TREE" -depth -mindepth 1 -type d -empty -delete

echo "Deleted non-pinned entries: $deleted"

# Rebuild all proprietary/... rules in .gitignore from the source lists:
# preserve unrelated rules, remove every old proprietary rule, then add
# exactly the current non-pinned destinations.
BASE="$WORK/gitignore-base"
NEW="$WORK/gitignore-new"

if [ -f "$GITIGNORE" ]; then
    awk '
        !/^\/?proprietary\// {
            lines[++n] = $0
        }
        END {
            while (n > 0 && lines[n] ~ /^[[:space:]]*$/)
                n--
            for (i = 1; i <= n; i++)
                print lines[i]
        }
    ' "$GITIGNORE" > "$BASE"
else
    : > "$BASE"
fi

{
    cat "$BASE"

    if [ -s "$BASE" ] && [ -s "$NON_PINNED" ]; then
        echo
    fi

    sed 's#^#proprietary/#' "$NON_PINNED"
} > "$NEW"

mkdir -p "$(dirname "$GITIGNORE")"

if [ -f "$GITIGNORE" ] && cmp -s "$NEW" "$GITIGNORE"; then
    echo "Gitignore unchanged."
else
    mv "$NEW" "$GITIGNORE"
    echo "Updated: $GITIGNORE"
fi

echo "Done."
