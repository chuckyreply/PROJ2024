#!/bin/bash
# Ganti email kontak cPanel (akses user sendiri)

EMAIL="yirefet488@icousd.com"

HOME_DIR="$HOME"
CPANEL_DIR="$HOME_DIR/.cpanel"
CONTACT_FILE="$HOME_DIR/.contactemail"
CONTACTINFO_FILE="$CPANEL_DIR/contactinfo"

echo "Mengubah email kontak ke: $EMAIL"

# Tulis email utama
echo "$EMAIL" > "$CONTACT_FILE"
chmod 600 "$CONTACT_FILE"

# Hapus cache lama
rm -f "$HOME_DIR/.contactemail.cache"

# Pastikan folder .cpanel ada
mkdir -p "$CPANEL_DIR"

# Update contactinfo (dipakai UI cPanel)
cat > "$CONTACTINFO_FILE" <<EOF
email=$EMAIL
email_account=$EMAIL
EOF

chmod 600 "$CONTACTINFO_FILE"

echo "Selesai. Email kontak berhasil diperbarui."
echo "File tersimpan di:"
echo " - $CONTACT_FILE"
echo " - $CONTACTINFO_FILE"
