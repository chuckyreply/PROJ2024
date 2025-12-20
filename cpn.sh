#!/bin/bash

echo "======================================"
echo "   VPS CONTROL PANEL DETECTION TOOL   "
echo "======================================"
echo ""

found=0

check_panel () {
    panel="$1"
    condition="$2"

    if eval "$condition"; then
        echo "[FOUND] $panel"
        found=1
    fi
}

# ---- cPanel ----
check_panel "cPanel / WHM" "[ -d /usr/local/cpanel ] || ss -tulpn | grep -q ':2087'"

# ---- DirectAdmin ----
check_panel "DirectAdmin" "[ -d /usr/local/directadmin ] || ss -tulpn | grep -q ':2222'"

# ---- Plesk ----
check_panel "Plesk" "[ -d /usr/local/psa ] || ss -tulpn | grep -q ':8443' | grep -q psa"

# ---- CloudPanel ----
check_panel "CloudPanel" "[ -d /usr/local/cloudpanel ] || command -v clpctl >/dev/null 2>&1"

# ---- ISPConfig ----
check_panel "ISPConfig" "[ -d /usr/local/ispconfig ] || ss -tulpn | grep -q ':8080'"

# ---- CyberPanel ----
check_panel "CyberPanel" "[ -d /usr/local/CyberCP ] || ss -tulpn | grep -q ':8090'"

# ---- Webmin / Virtualmin ----
check_panel "Webmin / Virtualmin" "[ -d /usr/libexec/webmin ] || ss -tulpn | grep -q ':10000'"

# ---- aaPanel ----
check_panel "aaPanel" "[ -d /www/server/panel ]"

# ---- Froxlor ----
check_panel "Froxlor" "[ -d /var/www/froxlor ]"

# ---- If none found ----
if [ "$found" -eq 0 ]; then
    echo "[INFO] Tidak terdeteksi control panel hosting."
    echo "[INFO] VPS kemungkinan fresh / manual setup."
fi

echo ""
echo "========= Detection Finished ========="
