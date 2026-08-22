#!/bin/bash
set -e

VENDOR=../../../vendor/sony/lilac
TREE="$VENDOR/proprietary"
STAGE=".pinned-stage"
GITIGNORE="$VENDOR/.gitignore"
FILES="proprietary-files-vendor.txt proprietary-files.txt"

# Build pinned.list from pinned entries in both proprietary files.
grep -hE '\|[0-9a-fA-F]{40}$' $FILES \
    | sed 's/^-//' > pinned.list

# Add non-pinned files to the vendor .gitignore.
tmp=$(mktemp)
[ -f "$GITIGNORE" ] && \
    sed '/^# BEGIN vendor-cleanup non-pinned$/,/^# END vendor-cleanup non-pinned$/d' \
        "$GITIGNORE" > "$tmp"

{
    cat "$tmp"
    echo "# BEGIN vendor-cleanup non-pinned"
    awk '
        /^[[:space:]]*(#|$)/ { next }
        /\|[0-9a-fA-F]{40}$/ { next }
        {
            sub(/^-/, "")
            n = split($0, path, ":")
            file = path[n]
            print "/proprietary/" file
        }
    ' $FILES
    echo "# END vendor-cleanup non-pinned"
} > "$GITIGNORE"
rm -f "$tmp"

# Start from a working tree that currently has the blobs (or a backup copy of it).
rm -rf "$STAGE" && mkdir -p "$STAGE"

# Verify and copy only pinned files.
while IFS='|' read -r file expected; do
    source="$TREE/$file"
    actual=$(sha1sum "$source" | cut -d' ' -f1)

    if [ "$actual" != "$expected" ]; then
        echo "Hash mismatch: $file"
        echo "  expected: $expected"
        echo "  actual:   $actual"
        exit 1
    fi

    mkdir -p "$STAGE/$(dirname "$file")"
    cp -a "$source" "$STAGE/$file"
done < pinned.list

# Replace proprietary/ with the pinned-only content.
rm -rf "$TREE"
mv "$STAGE" "$TREE"
