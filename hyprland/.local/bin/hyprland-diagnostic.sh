#!/bin/bash

# Hyprland Display Diagnostic Script
# This script helps diagnose display issues when system freezes after login

echo "========================================="
echo "HYPRLAND DISPLAY DIAGNOSTIC SCRIPT"
echo "========================================="
echo "Timestamp: $(date)"
echo "User: $(whoami)"
echo "Hostname: $(hostname)"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to safely read file content
safe_read() {
    local file="$1"
    if [ -f "$file" ]; then
        cat "$file" 2>/dev/null || echo "Error reading $file"
    else
        echo "File not found: $file"
    fi
}

echo "========================================="
echo "1. SYSTEM OVERVIEW"
echo "========================================="
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime)"
echo "Current runlevel: $(runlevel 2>/dev/null || echo "systemd mode")"
echo ""

echo "========================================="
echo "2. NVIDIA STATUS"
echo "========================================="
echo "NVIDIA Driver Version:"
if command_exists nvidia-smi; then
    nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null || echo "nvidia-smi failed"
else
    echo "nvidia-smi not found"
fi

echo ""
echo "NVIDIA Modules:"
lsmod | grep -i nvidia || echo "No NVIDIA modules loaded"

echo ""
echo "NVIDIA GPU Info:"
lspci | grep -i nvidia || echo "No NVIDIA GPU found"

echo ""
echo "NVIDIA Kernel Parameters:"
cat /proc/cmdline | grep -o 'nvidia[^[:space:]]*' || echo "No NVIDIA kernel parameters found"

echo ""
echo "NVIDIA DRM Flip Errors Check:"
echo "Checking for atomic commit flip timeout errors..."
if command_exists dmesg; then
    FLIP_ERRORS=$(dmesg 2>/dev/null | grep -i "flip\|atomic\|timeout" | grep -i nvidia | tail -5)
    if [ -n "$FLIP_ERRORS" ]; then
        echo "⚠️  Recent NVIDIA flip/atomic errors found:"
        echo "$FLIP_ERRORS"
    else
        echo "✓ No recent NVIDIA flip/atomic errors found"
    fi
    
    echo ""
    echo "Low-level DRM errors (critical - these happen before Hyprland):"
    DRM_ERRORS=$(dmesg 2>/dev/null | grep -i "drm.*nvidia\|nvidia.*drm" | grep -i "timeout\|flip\|atomic\|failed\|error" | tail -10)
    if [ -n "$DRM_ERRORS" ]; then
        echo "🚨 CRITICAL: DRM errors found at kernel level:"
        echo "$DRM_ERRORS"
    else
        echo "✓ No critical DRM errors found"
    fi
else
    echo "Cannot check dmesg (permission denied or not available)"
fi

echo ""
echo "NVIDIA GPU Memory and Performance:"
if command_exists nvidia-smi; then
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader 2>/dev/null || echo "nvidia-smi query failed"
else
    echo "nvidia-smi not available"
fi

echo ""

echo "========================================="
echo "3. MONITOR DETECTION"
echo "========================================="
echo "DRM Connectors Status:"
# Enable nullglob to handle empty glob patterns gracefully
shopt -s nullglob
for connector in /sys/class/drm/card*/card*-*/status; do
    if [ -f "$connector" ]; then
        connector_name=$(basename $(dirname "$connector"))
        status=$(cat "$connector" 2>/dev/null)
        echo "  $connector_name: $status"
    fi
done
shopt -u nullglob

echo ""
echo "Xrandr Output (if available):"
if command_exists xrandr; then
    xrandr 2>/dev/null | head -20 || echo "Xrandr failed or not available"
else
    echo "xrandr not available"
fi

echo ""
echo "Wayland Display Info:"
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "WAYLAND_DISPLAY: $WAYLAND_DISPLAY"
    if command_exists wlr-randr; then
        echo "wlr-randr output:"
        wlr-randr 2>/dev/null || echo "wlr-randr failed"
    else
        echo "wlr-randr not available"
    fi
else
    echo "Not in Wayland session"
fi

echo ""
echo "TTY and Console Information:"
echo "Current TTY: $(tty 2>/dev/null || echo 'unknown')"
echo "Current session: $(loginctl show-session $(loginctl --no-pager | grep $(whoami) | awk '{print $1}') 2>/dev/null || echo 'unknown')"
echo "Virtual console mode:"
if [ -f "/sys/class/tty/tty0/active" ]; then
    echo "Active VT: $(cat /sys/class/tty/tty0/active 2>/dev/null || echo 'unknown')"
else
    echo "VT info not available"
fi

echo ""

echo "========================================="
echo "4. HYPRLAND CONFIGURATION"
echo "========================================="
echo "Hyprland Config Location:"
HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
HYPR_CONFIG_DIR="$HOME/.config/hypr/config.d"

if [ -f "$HYPR_CONFIG" ]; then
    echo "Main config file: $HYPR_CONFIG"
    echo "Config structure:"
    cat "$HYPR_CONFIG" 2>/dev/null
    echo ""
    
    # Check if config.d directory exists
    if [ -d "$HYPR_CONFIG_DIR" ]; then
        echo "Config directory: $HYPR_CONFIG_DIR"
        echo "Available config files:"
        ls -la "$HYPR_CONFIG_DIR" 2>/dev/null
        echo ""
        
        echo "Environment Variables:"
        grep -E "^env\s*=" "$HYPR_CONFIG_DIR"/*.conf 2>/dev/null | head -10 || echo "No environment variables found"
        echo ""
        
        echo "Monitor Configuration:"
        grep -E "^monitor\s*=" "$HYPR_CONFIG_DIR"/*.conf 2>/dev/null | head -10 || echo "No monitor configuration found"
        echo ""
        
        echo "Exec-once Commands:"
        grep -E "^exec-once\s*=" "$HYPR_CONFIG_DIR"/*.conf 2>/dev/null | head -5 || echo "No exec-once commands found"
        echo ""
        
        echo "Key NVIDIA-related settings:"
        grep -E "(WLR_DRM_NO_ATOMIC|WLR_NO_HARDWARE_CURSORS|WLR_RENDERER_ALLOW_SOFTWARE)" "$HYPR_CONFIG_DIR"/*.conf 2>/dev/null || echo "No NVIDIA workarounds found"
    else
        echo "Config directory not found at $HYPR_CONFIG_DIR"
        echo ""
        echo "Environment Variables:"
        grep -E "^env\s*=" "$HYPR_CONFIG" | head -10
        echo ""
        echo "Monitor Configuration:"
        grep -E "^monitor\s*=" "$HYPR_CONFIG" | head -10
        echo ""
        echo "Exec-once Commands:"
        grep -E "^exec-once\s*=" "$HYPR_CONFIG" | head -5
    fi
else
    echo "Hyprland config not found at $HYPR_CONFIG"
fi

echo ""

echo "========================================="
echo "5. SYSTEM SERVICES"
echo "========================================="
echo "Display Manager Status:"
systemctl status ly 2>/dev/null || systemctl status lightdm 2>/dev/null || systemctl status gdm 2>/dev/null || echo "No known display manager found"

echo ""
echo "Hyprland Process:"
pgrep -fl hyprland || echo "Hyprland not running"

echo ""
echo "Related Processes:"
ps aux | grep -E "(waybar|wofi|mako|dunst)" | grep -v grep || echo "No related processes found"

echo ""
echo "Gaming-related Services Check:"
echo "Checking for potentially conflicting gaming services..."
GAMING_SERVICES="gamemoded gamemode irqbalance ananicy-cpp thermald"
for service in $GAMING_SERVICES; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "⚠️  $service is running - may cause conflicts"
        systemctl status "$service" --no-pager -l 2>/dev/null | head -3
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo "ℹ️  $service is enabled but not running"
    else
        echo "✓ $service is not active"
    fi
done

echo ""
echo "Gaming-related Processes:"
ps aux | grep -E "(gamemode|irqbalance|ananicy)" | grep -v grep || echo "No gaming processes found"

echo ""
echo "Gaming-related Packages Installed:"
if command_exists pacman; then
    GAMING_PACKAGES=$(pacman -Qq 2>/dev/null | grep -E "game|irq|ananicy|performance" | grep -v grep || echo "")
    if [ -n "$GAMING_PACKAGES" ]; then
        echo "⚠️  Found gaming-related packages:"
        echo "$GAMING_PACKAGES" | head -10
    else
        echo "✓ No obvious gaming packages found"
    fi
else
    echo "pacman not available"
fi

echo ""

echo "========================================="
echo "6. MEMORY AND SYSTEM RESOURCES"
echo "========================================="
echo "Memory Usage:"
free -h

echo ""
echo "System Load:"
cat /proc/loadavg

echo ""
echo "Critical sysctl values:"
echo "vm.max_map_count: $(sysctl -n vm.max_map_count 2>/dev/null || echo 'unknown')"
echo "vm.dirty_ratio: $(sysctl -n vm.dirty_ratio 2>/dev/null || echo 'unknown')"
echo "vm.dirty_background_ratio: $(sysctl -n vm.dirty_background_ratio 2>/dev/null || echo 'unknown')"

echo ""
echo "Performance/Gaming Settings:"
echo "CPU Governor:"
if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown"
else
    echo "CPU frequency scaling not available"
fi

echo "CPU Frequency Scaling:"
if command_exists cpupower; then
    cpupower frequency-info --policy 2>/dev/null | head -3 || echo "cpupower not available"
else
    echo "cpupower not installed"
fi

echo ""

echo "========================================="
echo "7. RECENT LOGS"
echo "========================================="
echo "Recent kernel messages (last 20 lines):"
dmesg | tail -20 2>/dev/null || echo "Cannot access dmesg"

echo ""
echo "NVIDIA-specific errors in recent logs:"
echo "Checking for DRM atomic commit flip timeout errors..."
if journalctl -k --no-pager -n 50 2>/dev/null | grep -i "nvidia.*flip\|nvidia.*atomic\|nvidia.*timeout\|drm.*flip.*timeout" | tail -5; then
    echo "⚠️  Found NVIDIA DRM errors above"
else
    echo "✓ No NVIDIA DRM flip/atomic errors in recent kernel logs"
fi

echo ""
echo "Recent journal entries for user session:"
journalctl --user -n 10 --no-pager 2>/dev/null || echo "Cannot access user journal"

echo ""
echo "Recent system journal entries:"
journalctl -n 10 --no-pager 2>/dev/null || echo "Cannot access system journal"

echo ""

echo "========================================="
echo "8. DIAGNOSTIC RECOMMENDATIONS"
echo "========================================="
echo "Based on common issues:"
echo ""

# Check for problematic sysctl values
vm_max_map=$(sysctl -n vm.max_map_count 2>/dev/null)
if [ "$vm_max_map" -gt 1000000 ] 2>/dev/null; then
    echo "⚠️  WARNING: vm.max_map_count is very high ($vm_max_map)"
    echo "   This can cause NVIDIA driver conflicts. Consider reverting to default."
    echo "   Check where it's set: grep -r \"vm.max_map_count\" /etc/sysctl.conf /etc/sysctl.d/"
    echo "   Fix: sudo sysctl vm.max_map_count=65536"
    echo "   Permanent fix: echo \"vm.max_map_count = 65536\" | sudo tee /etc/sysctl.d/10-vm-max-map-count.conf"
fi

vm_dirty=$(sysctl -n vm.dirty_ratio 2>/dev/null)
if [ "$vm_dirty" -lt 10 ] 2>/dev/null; then
    echo "⚠️  WARNING: vm.dirty_ratio is very low ($vm_dirty)"
    echo "   This can cause I/O timing issues. Consider reverting to default."
fi

# Check for NVIDIA-specific issues
if lsmod | grep -q nvidia; then
    echo "✓ NVIDIA modules are loaded"
    if ! grep -q "nvidia_drm.modeset=1" /proc/cmdline; then
        echo "⚠️  Consider adding nvidia_drm.modeset=1 to kernel parameters"
    fi
else
    echo "⚠️  No NVIDIA modules loaded - this may be the issue"
fi

# Check for gaming services that might conflict
GAMING_SERVICES="gamemoded gamemode irqbalance ananicy-cpp"
for service in $GAMING_SERVICES; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "⚠️  $service is running - may cause NVIDIA conflicts"
        echo "   Consider: sudo systemctl disable $service && sudo systemctl stop $service"
    fi
done

# Check for low-level DRM issues
DRM_ERRORS=$(dmesg 2>/dev/null | grep -i "drm.*nvidia\|nvidia.*drm" | grep -i "timeout\|flip\|atomic\|failed\|error" | tail -1)
if [ -n "$DRM_ERRORS" ]; then
    echo "🚨 CRITICAL: Low-level DRM errors detected (happens before Hyprland)"
    echo "   This suggests fundamental NVIDIA driver issues"
    echo "   Try additional kernel parameters or consider different NVIDIA driver version"
fi

# Check Hyprland environment
HYPR_CONFIG_DIR="$HOME/.config/hypr/config.d"
if [ -f "$HYPR_CONFIG" ]; then
    # Check both main config and config.d files
    if [ -d "$HYPR_CONFIG_DIR" ]; then
        CONFIG_FILES="$HYPR_CONFIG $HYPR_CONFIG_DIR/*.conf"
    else
        CONFIG_FILES="$HYPR_CONFIG"
    fi
    
    if grep -q "WLR_DRM_NO_ATOMIC,1" $CONFIG_FILES 2>/dev/null; then
        echo "✓ WLR_DRM_NO_ATOMIC is set (good for NVIDIA)"
    else
        echo "⚠️  Consider adding: env = WLR_DRM_NO_ATOMIC,1"
    fi
    
    if grep -q "WLR_NO_HARDWARE_CURSORS,1" $CONFIG_FILES 2>/dev/null; then
        echo "✓ WLR_NO_HARDWARE_CURSORS is set (good for NVIDIA)"
    else
        echo "⚠️  Consider adding: env = WLR_NO_HARDWARE_CURSORS,1"
    fi
fi

echo ""
echo "Common fixes to try:"
echo "1. Remove any gaming sysctl optimizations"
echo "2. Check /etc/sysctl.d/ for problematic files"
echo "3. Disable problematic gaming services: sudo systemctl disable gamemoded"
echo "4. Restart display manager: sudo systemctl restart ly"
echo "5. Check kernel parameters for NVIDIA options"
echo "6. Verify monitor connections and cables"
echo ""
echo "CRITICAL: If DRM errors found above, try these kernel parameters:"
echo "  Current: nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
echo "  Add: nvidia_drm.modeset=1 nvidia_drm.fbdev=1 nvidia.NVreg_UsePageAttributeTable=1"
echo "  Or try: nvidia_drm.modeset=1 nvidia_drm.fbdev=1 nvidia.NVreg_EnableGpuFirmware=0"
echo "  Last resort: nvidia_drm.modeset=1 nvidia_drm.fbdev=1 video=efifb:off nouveau.modeset=0"
echo ""
echo "Manual commands to check for NVIDIA flip errors:"
echo "  dmesg | grep -i \"flip\\|atomic\\|timeout\" | grep -i nvidia"
echo "  journalctl -k --no-pager | grep -i \"nvidia.*flip\\|drm.*flip.*timeout\""
echo "  watch -n 1 'dmesg | tail -10 | grep -i nvidia'"
echo ""
echo "Manual commands for low-level DRM debugging:"
echo "  dmesg | grep -i \"drm.*nvidia\\|nvidia.*drm\" | grep -i \"timeout\\|flip\\|atomic\""
echo "  sudo dmesg -w | grep -i nvidia  # Watch for new errors in real-time"
echo "  cat /sys/kernel/debug/dri/*/state  # DRM state (if debugfs mounted)"
echo "  journalctl -k --no-pager --since=\"5 minutes ago\" | grep -i nvidia"
echo ""
echo "Manual commands to check for gaming services:"
echo "  systemctl list-units --type=service | grep -E \"game|irq|ananicy\""
echo "  pacman -Qq | grep -E \"game|irq|ananicy|performance\""
echo "  systemctl disable gamemoded && systemctl stop gamemoded"

echo ""
echo "========================================="
echo "DIAGNOSTIC COMPLETE"
echo "=========================================" 
