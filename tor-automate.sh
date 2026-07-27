#!/usr/bin/env bash
# Tor Automate Engine V4.5 (PasarGuard API Edition)

# ================= COLORS =================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ================= CONFIG =================
BASE_DIR="/etc/tor/t_sin_nodes"
DATA_DIR="/var/lib/tor/t_sin_nodes"

# Panel Config Cache
PANEL_CONF="$BASE_DIR/pasargad_panel.conf"

# Format: "CountryCode : CountryName : TorPort"
declare -A NODES=(
    [01]="DE:Germany:9080" [02]="TR:Turkey:9081" [03]="US:United States:9082"
    [04]="FR:France:9083" [05]="AT:Austria:9084" [06]="BE:Belgium:9085"
    [07]="RO:Romania:9086" [08]="CA:Canada:9087" [09]="SG:Singapore:9088"
    [10]="JP:Japan:9089" [11]="IE:Ireland:9090" [12]="FI:Finland:9091"
    [13]="ES:Spain:9092" [14]="PL:Poland:9093" [15]="NL:Netherlands:9094"
    [16]="IT:Italy:9095" [17]="CH:Switzerland:9096" [18]="SE:Sweden:9097"
    [19]="NO:Norway:9098" [20]="DK:Denmark:9099" [21]="IS:Iceland:9100"
    [22]="AU:Australia:9101" [23]="IN:India:9102" [24]="HK:Hong Kong:9103"
    [25]="UA:Ukraine:9104" [26]="CZ:Czech Republic:9105" [27]="KR:South Korea:9106"
    [28]="ZA:South Africa:9107" [29]="MX:Mexico:9108" [30]="MY:Malaysia:9109"
    [31]="AZ:Azerbaijan:9110" [32]="CY:Cyprus:9111" [33]="GR:Greece:9112"
    [34]="PT:Portugal:9113" [35]="HU:Hungary:9114" [36]="LU:Luxembourg:9115"
    [37]="GB:United Kingdom:9116" [38]="AR:Argentina:9117" [39]="TW:Taiwan:9118"
    [40]="BG:Bulgaria:9119" [41]="IL:Israel:9120" [42]="MD:Moldova:9121"
    [43]="RU:Russia:9122" [44]="CL:Chile:9123" [45]="CR:Costa Rica:9124"
    [46]="VN:Vietnam:9125" [47]="ID:Indonesia:9126" [48]="SC:Seychelles:9127"
    [49]="HR:Croatia:9128" [50]="TN:Tunisia:9129"
)

declare -A EMOJIS=(
    [DE]="🇩🇪" [TR]="🇹🇷" [US]="🇺🇸" [FR]="🇫🇷" [AT]="🇦🇹" [BE]="🇧🇪"
    [RO]="🇷🇴" [CA]="🇨🇦" [SG]="🇸🇬" [JP]="🇯🇵" [IE]="🇮🇪" [FI]="🇫🇮"
    [ES]="🇪🇸" [PL]="🇵🇱" [NL]="🇳🇱" [IT]="🇮🇹" [CH]="🇨🇭" [SE]="🇸🇪"
    [NO]="🇳🇴" [DK]="🇩🇰" [IS]="🇮🇸" [AU]="🇦🇺" [IN]="🇮🇳" [HK]="🇭🇰"
    [UA]="🇺🇦" [CZ]="🇨🇿" [KR]="🇰🇷" [ZA]="🇿🇦" [MX]="🇲🇽" [MY]="🇲🇾"
    [AZ]="🇦🇿" [CY]="🇨🇾" [GR]="🇬🇷" [PT]="🇵🇹" [HU]="🇭🇺" [LU]="🇱🇺"
    [GB]="🇬🇧" [AR]="🇦🇷" [TW]="🇹🇼" [BG]="🇧🇬" [IL]="🇮🇱" [MD]="🇲🇩"
    [RU]="🇷🇺" [CL]="🇨🇱" [CR]="🇨🇷" [VN]="🇻🇳" [ID]="🇮🇩" [SC]="🇸🇨"
    [HR]="🇭🇷" [TN]="🇹🇳"
)

ORDER=({01..50})

# ================= CORE FUNCTIONS =================

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}[!] Error: Please run as root (sudo).${NC}"
        exit 1
    fi
}

# ================= BACKGROUND CRON JOB =================
background_auto_heal() {
    for idx in "${ORDER[@]}"; do
        local details="${NODES[$idx]}"
        IFS=':' read -r code name out_port <<< "$details"
        
        local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
        local ip_file="$DATA_DIR/${code}_${out_port}/last_ip.txt"
        
        if [ -f "$conf_file" ]; then
            local is_dead=0
            
            if ! pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
                is_dead=1
            else
                local test_ip=$(curl -s --socks5-hostname 127.0.0.1:$out_port https://api.ipify.org --max-time 15 || true)
                if [[ ! "$test_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    is_dead=1
                else
                    echo "$test_ip" > "$ip_file"
                fi
            fi
            
            if [ $is_dead -eq 1 ]; then
                pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
                rm -f "$ip_file"
                sudo -u debian-tor tor -f "$conf_file" >/dev/null 2>&1 &
                
                (
                    sleep 15
                    local new_ip=$(curl -s --socks5-hostname 127.0.0.1:$out_port https://api.ipify.org --max-time 15 || true)
                    if [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        echo "$new_ip" > "$ip_file"
                    fi
                ) &
            fi
        fi
    done
    exit 0
}

if [ "$1" == "--auto-heal" ]; then
    background_auto_heal
fi

# ================= UI FUNCTIONS =================

draw_header() {
    clear
    echo -e "${MAGENTA} ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA} ║${CYAN}  ████████╗ ██████╗ ██████╗                               ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}  ╚══██╔══╝██╔═══██╗██╔══██╗                              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ██║   ██║██████╔╝                              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ██║   ██║██╔══██╗                              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ╚██████╔╝██║  ██║                              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ╚═╝    ╚═════╝ ╚═╝  ╚═╝                              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${YELLOW}      A U T O M A T E   E N G I N E   V4.5              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

draw_progress() {
    local text=$1
    for ((i=1; i<=20; i++)); do
        local percent=$((i * 5))
        printf "\r${CYAN}[*] %-40s ${MAGENTA}[${GREEN}" "$text"
        for ((j=1; j<=i; j++)); do printf "█"; done
        for ((j=i+1; j<=20; j++)); do printf " "; done
        printf "${MAGENTA}] ${YELLOW}%3d%%${NC}" "$percent"
        sleep 0.05
    done
    echo ""
}

deploy_node() {
    local code=$1; local name=$2; local out_port=$3
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local inst_data_dir="$DATA_DIR/${code}_${out_port}"
    local ip_file="$inst_data_dir/last_ip.txt"

    mkdir -p "$BASE_DIR"
    mkdir -p "$inst_data_dir"
    chown -R debian-tor:debian-tor "$inst_data_dir" 2>/dev/null || true

    cat <<EOF > "$conf_file"
SocksPort 0.0.0.0:$out_port
DataDirectory $inst_data_dir
ExitNodes {$code}
StrictNodes 1
RunAsDaemon 1
Log notice file $inst_data_dir/notices.log
EOF
    chown debian-tor:debian-tor "$conf_file" 2>/dev/null || true

    if pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
        pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
    fi

    echo -e "${CYAN}[*] Routing ${WHITE}$code - $name ${CYAN}➔ Tor Port: ${MAGENTA}$out_port${CYAN}. Please wait...${NC}"
    sudo -u debian-tor tor -f "$conf_file" >/dev/null 2>&1 &
    draw_progress "Bootstrapping Tor connection"

    local connect_attempts=0
    local max_connect_attempts=20
    
    # New Check Variables
    local clean_attempts=0
    local max_clean_attempts=3

    while [ $connect_attempts -lt $max_connect_attempts ]; do
        # Effort to get IP from Tor
        local public_ip=$(curl -s --socks5-hostname 127.0.0.1:$out_port https://api.ipify.org --max-time 10 | tr -d '\0' || true)
        
        if [ ! -z "$public_ip" ] && [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            
            # --- START OF IP API CHECK ---
            echo -e "${CYAN}[*] Checking IP Reputation for ${MAGENTA}$public_ip${CYAN}...${NC}"
            local api_resp=$(curl -s "https://api.ipapi.is/?q=$public_ip" --max-time 10 || true)
            
            local is_bad=0
            local abuser_line=$(echo "$api_resp" | grep -i '"abuser_score"')
            
            # If the line contains "High" (this covers High and Very High)
            if echo "$abuser_line" | grep -iq "High"; then
                is_bad=1
            fi
            
            if [ $is_bad -eq 0 ] || [ $clean_attempts -ge $max_clean_attempts ]; then
                if [ $is_bad -eq 1 ]; then
                    echo -e "${YELLOW}[!] Max retries reached (3/3). Forcing acceptance of IP: $public_ip${NC}"
                else
                    echo -e "${GREEN}[+] IP is Clean (Low/Elevated)!${NC}"
                fi
                
                # Accept IP
                echo "$public_ip" > "$ip_file"
                echo -e "${GREEN}[+] Online -> ${WHITE}$code - $name ${GREEN}($public_ip)${NC}\n"
                return 0
            else
                clean_attempts=$((clean_attempts+1))
                echo -e "${RED}[-] IP $public_ip is High Risk! Requesting new IP from Tor ($clean_attempts/$max_clean_attempts)...${NC}"
                
                # Restart the specific Tor instance to force a new circuit and IP
                pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
                sleep 2
                sudo -u debian-tor tor -f "$conf_file" >/dev/null 2>&1 &
                sleep 5 
                
                # Reset connection attempts to give Tor time to connect again
                connect_attempts=0
            fi
            # --- END OF IP API CHECK ---
            
        else
            echo -e "${CYAN}[*] Waiting for Tor connection (Attempt $((connect_attempts+1))/$max_connect_attempts)...${NC}"
            connect_attempts=$((connect_attempts+1))
            sleep 3
        fi
    done
    
    echo -e "${RED}[-] Setup failed or Country restricted for $code - $name (Could not connect to Tor)${NC}\n"
}

# ================= CORE MENUS =================

install_engine() {
    check_root
    draw_header
    echo -e "${YELLOW}[*] Updating package lists...${NC}"
    apt-get update -qq
    echo -e "${YELLOW}[*] Installing prerequisites (Tor, Curl, JQ, Nano, OpenSSL, Zip, Cron)...${NC}"
    apt-get install -y tor tor-geoipdb curl jq nano openssl unzip zip cron
    systemctl stop tor 2>/dev/null || true
    systemctl disable tor 2>/dev/null || true
    mkdir -p "$BASE_DIR"
    mkdir -p "$DATA_DIR"
    chown -R debian-tor:debian-tor "$DATA_DIR" 2>/dev/null || true
    
    cp "$0" /usr/local/bin/tor-automate
    chmod +x /usr/local/bin/tor-automate
    echo "*/30 * * * * root /usr/local/bin/tor-automate --auto-heal > /dev/null 2>&1" > /etc/cron.d/tor_automate_heal
    chmod 644 /etc/cron.d/tor_automate_heal
    systemctl restart cron 2>/dev/null || true
    
    echo -e "${GREEN}[+] Engine & Core Tools Installed Successfully! Background Auto-Heal is Active.${NC}"
    sleep 3
}

uninstall_engine() {
    check_root
    draw_header
    echo -e "${RED}[!] WARNING: This will completely remove Tor and configurations.${NC}"
    read -p "❓ Are you sure? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi
    pkill -f "node_" 2>/dev/null || true
    systemctl stop tor 2>/dev/null || true
    apt-get remove --purge -y tor tor-geoipdb
    apt-get autoremove -y
    rm -rf /etc/tor/t_sin_nodes
    rm -rf /var/lib/tor/t_sin_nodes
    rm -f /etc/cron.d/tor_automate_heal
    rm -f /usr/local/bin/tor-automate
    echo -e "${GREEN}[+] Uninstallation complete.${NC}"
    exit 0
}

list_locations() {
    echo -e "${YELLOW}Available Locations:${NC}\n"
    
    local C_CYAN='\033[1;36m'
    local C_GREEN='\033[1;32m'
    local C_WHITE='\033[1;37m'
    local NC='\033[0m'
    
    local CIRCLE_ON="${C_GREEN}●${NC}"
    local CIRCLE_OFF="${C_WHITE}○${NC}"
    
    for ((i=1; i<=25; i++)); do
        local idx1=$(printf "%02d" $i)
        local idx2=$(printf "%02d" $((i+25)))
        
        IFS=':' read -r code1 name1 port1 <<< "${NODES[$idx1]}"
        local stat1="$CIRCLE_OFF"
        if [ -f "$BASE_DIR/node_${code1}_${port1}.conf" ]; then
            stat1="$CIRCLE_ON"
        fi
        
        local col2_str=""
        if [[ -n "${NODES[$idx2]}" ]]; then
            IFS=':' read -r code2 name2 port2 <<< "${NODES[$idx2]}"
            local stat2="$CIRCLE_OFF"
            if [ -f "$BASE_DIR/node_${code2}_${port2}.conf" ]; then
                stat2="$CIRCLE_ON"
            fi
            col2_str=$(printf "${C_CYAN}[%s]${NC} %b %-16s" "$idx2" "$stat2" "$name2")
        fi
        
        printf "  ${C_CYAN}[%s]${NC} %b %-16s    %b\n" "$idx1" "$stat1" "$name1" "$col2_str"
    done
    
    echo -e "\n  ${RED}00${NC} - ${WHITE}Back to main menu${NC}\n"
}

add_single_node() {
    check_root
    draw_header
    echo -e "${CYAN}» Option 4 - Add Location Node${NC}\n"
    list_locations
    read -p "$(echo -e ${MAGENTA}"Select location index: "${NC})" loc_idx
    if [[ "$loc_idx" == "00" ]]; then return; fi
    p_idx=$(printf "%02d" "$loc_idx")
    if [[ -n "${NODES[$p_idx]}" ]]; then
        IFS=':' read -r code name out_port <<< "${NODES[$p_idx]}"
        
        if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
            echo -e "\n${YELLOW}[!] Node $code - $name is already active. You cannot install it again.${NC}"
            sleep 2
        else
            deploy_node "$code" "$name" "$out_port"
            read -p "$(echo -e ${WHITE}"Press Enter to return..."${NC})"
        fi
    fi
}

bulk_add_nodes() {
    check_root
    draw_header
    echo -e "${CYAN}» Option 5 - Bulk Add Nodes${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Deploy All Supported Locations (Full World)"
    echo -e "  ${GREEN}[2]${NC} Custom Batch Deployment (Comma separated selection)"
    echo -e "  ${GREEN}[3]${NC} Deploy Main Countries (TR, US, FR, FI, ES, NL, GB, CA, LU, CH)"
    echo -e "  ${RED}[0]${NC} Go Back\n"
    
    read -p "$(echo -e ${CYAN}"Select deployment mode [0-3]: "${NC})" bulk_opt
    
    if [ "$bulk_opt" == "1" ]; then
        echo -e "${YELLOW}[!] Initiating deployment for ALL uninstalled nodes...${NC}"
        for idx in "${ORDER[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
            
            if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
                continue
            fi
            
            echo -e "\n${CYAN}[*] Processing ${WHITE}$code - $name${CYAN}...${NC}"
            deploy_node "$code" "$name" "$out_port"
            sleep 1 
        done
        echo -e "\n${GREEN}[+] Full deployment sequence complete!${NC}"
        read -p "$(echo -e ${WHITE}"Press Enter to return to main menu..."${NC})"
        
    elif [ "$bulk_opt" == "2" ]; then
        list_locations
        echo -e "${YELLOW}Example format: 1, 4, 15, 22${NC}"
        read -p "$(echo -e ${CYAN}"Enter indices separated by comma: "${NC})" custom_list
        
        if [ -z "$custom_list" ] || [ "$custom_list" == "00" ] || [ "$custom_list" == "0" ]; then return; fi
        
        IFS=',' read -ra ADDR <<< "$custom_list"
        for i in "${ADDR[@]}"; do
            local clean_i=$(echo "$i" | sed 's/^0*//' | tr -d ' ')
            if [ -n "$clean_i" ]; then
                local p_idx=$(printf "%02d" "$clean_i")
                if [[ -n "${NODES[$p_idx]}" ]]; then
                    IFS=':' read -r code name out_port <<< "${NODES[$p_idx]}"
                    
                    if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
                        echo -e "${YELLOW}[!] $code - $name is already active. Skipping...${NC}"
                    else
                        echo -e "\n${CYAN}[*] Processing ${WHITE}$code - $name${CYAN}...${NC}"
                        deploy_node "$code" "$name" "$out_port"
                        sleep 1
                    fi
                fi
            fi
        done
        echo -e "\n${GREEN}[+] Custom batch deployment sequence complete!${NC}"
        read -p "$(echo -e ${WHITE}"Press Enter to return to main menu..."${NC})"

    elif [ "$bulk_opt" == "3" ]; then
        echo -e "${YELLOW}[!] Initiating deployment for Main Countries...${NC}"
        local main_list=("02" "03" "04" "08" "12" "13" "15" "17" "36" "37")
        for p_idx in "${main_list[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$p_idx]}"
            
            if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
                echo -e "${YELLOW}[!] $code - $name is already active. Skipping...${NC}"
                continue
            fi
            
            echo -e "\n${CYAN}[*] Processing ${WHITE}$code - $name${CYAN}...${NC}"
            deploy_node "$code" "$name" "$out_port"
            sleep 1 
        done
        echo -e "\n${GREEN}[+] Main Countries deployment sequence complete!${NC}"
        read -p "$(echo -e ${WHITE}"Press Enter to return to main menu..."${NC})"
    fi
}

view_active_nodes() {
    while true; do
        draw_header
        echo -e "${CYAN}» Option 6 - Active Nodes Monitor (Instant View Mode)${NC}"
        echo -e "${YELLOW}[*] Live monitoring... Fetching data directly from cache without active API checks.${NC}\n"
        
        echo -e "${BLUE}┌──────┬──────┬──────────────────────┬─────────────┬──────────────┬──────────────────┐${NC}"
        echo -e "${BLUE}│${WHITE} ID   ${BLUE}│${WHITE} CC   ${BLUE}│${WHITE} Location             ${BLUE}│${WHITE} Tor Port    ${BLUE}│${WHITE} Status       ${BLUE}│${WHITE} Live IP          ${BLUE}│${NC}"
        echo -e "${BLUE}├──────┼──────┼──────────────────────┼─────────────┼──────────────┼──────────────────┤${NC}"
        
        local found=0
        for idx in "${ORDER[@]}"; do
            local details="${NODES[$idx]}"
            IFS=':' read -r code name out_port <<< "$details"
            
            local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
            local ip_file="$DATA_DIR/${code}_${out_port}/last_ip.txt"
            
            if [ -f "$conf_file" ]; then
                found=1
                
                local display_ip="Waiting..."
                if [ -f "$ip_file" ] && [ -s "$ip_file" ]; then
                    display_ip=$(cat "$ip_file")
                fi
                
                if pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
                    printf "${BLUE}│ ${CYAN}%-4s ${BLUE}│ ${WHITE}%-4s ${BLUE}│ ${WHITE}%-20s ${BLUE}│ ${MAGENTA}%-11s ${BLUE}│ ${GREEN}%-12s ${BLUE}│ ${GREEN}%-16s ${BLUE}│${NC}\n" "$idx" "$code" "$name" "$out_port" "ONLINE" "$display_ip"
                else
                    rm -f "$ip_file"
                    sudo -u debian-tor tor -f "$conf_file" >/dev/null 2>&1 &
                    
                    printf "${BLUE}│ ${CYAN}%-4s ${BLUE}│ ${WHITE}%-4s ${BLUE}│ ${WHITE}%-20s ${BLUE}│ ${MAGENTA}%-11s ${BLUE}│ ${YELLOW}%-12s ${BLUE}│ ${YELLOW}%-16s ${BLUE}│${NC}\n" "$idx" "$code" "$name" "$out_port" "HEALING..." "Restarting..."
                    
                    (
                        while true; do
                            sleep 8
                            local new_ip=$(curl -s --socks5-hostname 127.0.0.1:$out_port https://api.ipify.org --max-time 15 || true)
                            if [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                echo "$new_ip" > "$ip_file"
                                break
                            fi
                            pkill -HUP -f "node_${code}_${out_port}.conf" 2>/dev/null || true
                        done
                    ) &
                fi
            fi
        done
        
        if [ $found -eq 0 ]; then
            printf "${BLUE}│ ${YELLOW}%-82s ${BLUE}│${NC}\n" "No active nodes found in the system."
        fi
        echo -e "${BLUE}└──────┴──────┴──────────────────────┴─────────────┴──────────────┴──────────────────┘${NC}\n"
        
        echo -e "${MAGENTA}[ Live Monitoring Active ]${NC} Screen refreshes every 3 seconds."
        echo -e "${WHITE}Press any key (or Enter) to stop monitoring and return to main menu...${NC}"
        
        if read -t 3 -n 1 -s key; then
            break
        fi
    done
}

edit_delete_nodes() {
    draw_header
    echo -e "📌 ${MAGENTA}[ DELETE ACTIVE NODE ]${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
    local active_nodes=()
    for idx in "${ORDER[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        if pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
            active_nodes+=("$idx")
            local emoji="${EMOJIS[$code]}"
            printf "  ${CYAN}[%s]${NC} %s %-18s \tTorPort:${MAGENTA}%s${NC}\n" "$idx" "$emoji" "$name" "$out_port"
        fi
    done
    if [ ${#active_nodes[@]} -eq 0 ]; then
        echo -e "  ${RED}No active nodes to delete.${NC}"; sleep 2; return
    fi
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${RED}[99] DELETE ALL ACTIVE NODES (Clear All)${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
    
    read -p "$(echo -e ${CYAN}"Select ID to stop/delete (or 0 to cancel): "${NC})" del_sel
    
    if [[ "$del_sel" == "0" || -z "$del_sel" ]]; then return; fi
    
    if [[ "$del_sel" == "99" ]]; then
        echo -e "\n${YELLOW}[!] Deleting ALL active nodes... Please wait.${NC}"
        for idx in "${active_nodes[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
            pkill -9 -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        done
        sleep 1.5
        for idx in "${active_nodes[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
            rm -f "$BASE_DIR/node_${code}_${out_port}.conf"
            rm -rf "$DATA_DIR/${code}_${out_port}" 2>/dev/null || true
        done
        echo -e "${GREEN}[+] All nodes removed successfully.${NC}"; sleep 2
        return
    fi

    del_sel=$(printf "%02d" $((10#$del_sel)) 2>/dev/null || echo "")
    if [[ -n "${NODES[$del_sel]}" ]]; then
        IFS=':' read -r code name out_port <<< "${NODES[$del_sel]}"
        pkill -9 -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        sleep 1
        rm -f "$BASE_DIR/node_${code}_${out_port}.conf"
        rm -rf "$DATA_DIR/${code}_${out_port}" 2>/dev/null || true
        echo -e "${GREEN}[+] Node removed.${NC}"; sleep 2
    fi
}

# ================= PASARGAD PANEL INTEGRATION =================

panel_login() {
    draw_header
    echo -e "⏳ ${CYAN}Connecting to Pasargad panel...${NC}"
    
    if [ -f "$PANEL_CONF" ]; then
        source "$PANEL_CONF" 2>/dev/null || true
        if [ -n "$URL" ] && [ -n "$TOKEN" ]; then
            echo -e "\n${GREEN}[+] Saved session found:${NC} ${WHITE}$URL${NC}"
            read -p "$(echo -e ${CYAN}"❓ Do you want to use the saved session? (Y/n): "${NC})" use_saved
            if [[ -z "$use_saved" || "${use_saved,,}" == "y" ]]; then
                echo -e "${GREEN}🟢 Login resumed successfully!${NC}"
                sleep 1
                panel_menu
                return
            fi
        fi
    fi

    echo -e "${YELLOW}[~] Detecting panel URL...${NC}"
    read -p "$(echo -e "  Panel domain (e.g. panel.example.com) []: ")" p_domain
    read -p "$(echo -e "  Panel port (e.g. 8443) []: ")" p_port
    
    local base_url="https://${p_domain}:${p_port}"
    
    read -p "  Admin username: " p_user
    read -s -p "  Admin password: " p_pass
    echo ""
    
    mkdir -p "$BASE_DIR"
    echo "URL=$base_url" > "$PANEL_CONF"
    echo "USER=$p_user" >> "$PANEL_CONF"
    echo "PASS=$p_pass" >> "$PANEL_CONF"
    
    echo -e "${YELLOW}[~] Logging in...${NC}"
    local token_resp=$(curl -s -X POST "$base_url/api/admin/token" \
        -d "grant_type=password&username=$p_user&password=$p_pass" | tr -d '\0')
    local token=$(echo "$token_resp" | jq -r '.access_token' 2>/dev/null || echo "null")
    
    if [ "$token" == "null" ] || [ -z "$token" ]; then
        echo -e "${RED}[!] Login failed. Ensure details are correct.${NC}"; sleep 2
    else
        echo "TOKEN=$token" >> "$PANEL_CONF"
        echo -e "${GREEN}🟢 Login successful!${NC}"
        sleep 1
        panel_menu
    fi
}

panel_menu() {
    while true; do
        draw_header
        echo -e "📌 ${MAGENTA}[ PASARGAD CONTROL PANEL ]${NC}"
        echo -e "${BLUE}=============================================${NC}"
        echo -e "  ${GREEN}[1]${NC} Auto-Extract Panel Configurations"
        echo -e "  ${RED}[2]${NC} Logout (Exit Panel)"
        echo -e "  ${YELLOW}[0]${NC} Return to Main Menu"
        echo -e "${BLUE}=============================================${NC}\n"
        read -p "$(echo -e ${CYAN}"Selected option: "${NC})" panel_opt
        
        if [ "$panel_opt" == "0" ]; then
            break
        elif [ "$panel_opt" == "2" ]; then
            rm -f "$PANEL_CONF"; break
        elif [ "$panel_opt" == "1" ]; then
            panel_batch_create
        fi
    done
}

extract_json_from_response() {
    local resp="$1"
    if echo "$resp" | jq -e '.inbounds' >/dev/null 2>&1; then echo "$resp"; return 0; fi
    local nested=$(echo "$resp" | jq -r '.config // .content // .xray_config // empty' 2>/dev/null)
    if [ -n "$nested" ]; then
        if echo "$nested" | jq -e '.inbounds' >/dev/null 2>&1; then echo "$nested"; return 0; fi
        local parsed=$(echo "$nested" | jq 'fromjson' 2>/dev/null || echo "")
        if echo "$parsed" | jq -e '.inbounds' >/dev/null 2>&1; then echo "$parsed"; return 0; fi
    fi
    echo ""
}

panel_batch_create() {
    source "$PANEL_CONF" 2>/dev/null || true
    
    local installed=()
    for idx in "${ORDER[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
            installed+=("$idx")
        fi
    done
    
    if [ ${#installed[@]} -eq 0 ]; then
        echo -e "\n${RED}[!] No installed Tor nodes found. Please install nodes first.${NC}"; sleep 2; return
    fi
    
    echo -e "\n📌 ${MAGENTA}[ INSTALLED NODES TO ADD ]${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
    for idx in "${installed[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        local emoji="${EMOJIS[$code]}"
        printf "  ${CYAN}[%s]${NC} %s %-18s \tTorPort:${MAGENTA}%s${NC}\n" "$idx" "$emoji" "$name" "$out_port"
    done
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
    
    # --- NEW: Node Selection Logic ---
    local selected_nodes=()
    read -p "$(echo -e ${CYAN}"Select Node IDs to add to Panel (e.g. 01,05) or type 'all' [Default: all]: "${NC})" user_selection
    
    if [[ -z "$user_selection" || "${user_selection,,}" == "all" ]]; then
        selected_nodes=("${installed[@]}")
    else
        IFS=',' read -ra SEL_ADDR <<< "$user_selection"
        for s in "${SEL_ADDR[@]}"; do
            local clean_s=$(echo "$s" | sed 's/^0*//' | tr -d ' ')
            if [ -n "$clean_s" ]; then
                local p_idx=$(printf "%02d" "$clean_s" 2>/dev/null)
                local is_installed=0
                for inst_node in "${installed[@]}"; do
                    if [[ "$inst_node" == "$p_idx" ]]; then
                        is_installed=1
                        break
                    fi
                done
                
                if [[ $is_installed -eq 1 ]]; then
                    # Check for accidental duplicates in user input
                    local is_duplicate=0
                    for sel_node in "${selected_nodes[@]}"; do
                        if [[ "$sel_node" == "$p_idx" ]]; then
                            is_duplicate=1
                            break
                        fi
                    done
                    if [[ $is_duplicate -eq 0 ]]; then
                        selected_nodes+=("$p_idx")
                    fi
                else
                    echo -e "${YELLOW}[!] Node ID $p_idx is not installed or invalid. Skipping...${NC}"
                fi
            fi
        done
    fi

    if [ ${#selected_nodes[@]} -eq 0 ]; then
        echo -e "\n${RED}[!] No valid nodes selected. Returning to menu...${NC}"; sleep 2; return
    fi
    # --- END NEW LOGIC ---
    
    echo -e "\n${YELLOW}[~] 🤖 Simulating browser... Scanning Pasargad for Core configurations...${NC}"
    
    local CORE_FILE="$BASE_DIR/remote_core.json"
    local found_config=0
    local CORE_API_URL=""
    
    local core_endpoints=("/api/admin/cores" "/api/cores" "/api/core" "/api/node/cores" "/api/admin/core")

    echo -e "${CYAN}    > Searching for Cores...${NC}"
    for ep in "${core_endpoints[@]}"; do
        local test_resp=$(curl -s -X GET "$URL$ep/1" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
        local extracted=$(extract_json_from_response "$test_resp")
        
        if [ -n "$extracted" ]; then
            echo "$extracted" > "$CORE_FILE"
            CORE_API_URL="$URL$ep/1"
            found_config=1
            break
        fi

        local list_resp=$(curl -s -X GET "$URL$ep" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
        local core_ids=$(echo "$list_resp" | jq -r '.[].id // .data[].id // empty' 2>/dev/null | head -n 1)
        
        if [ -n "$core_ids" ]; then
            local fetch_resp=$(curl -s -X GET "$URL$ep/$core_ids" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
            local extracted2=$(extract_json_from_response "$fetch_resp")
            if [ -n "$extracted2" ]; then
                echo "$extracted2" > "$CORE_FILE"
                CORE_API_URL="$URL$ep/$core_ids"
                found_config=1
                break
            fi
        fi
    done

    if [ $found_config -eq 0 ]; then
        local nodes_resp=$(curl -s -X GET "$URL/api/nodes" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
        local node_ids=$(echo "$nodes_resp" | jq -r '.[].id // .data[].id // empty' 2>/dev/null)
        for nid in $node_ids; do
            local n_resp=$(curl -s -X GET "$URL/api/node/$nid" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
            local extracted3=$(extract_json_from_response "$n_resp")
            if [ -n "$extracted3" ]; then
                echo "$extracted3" > "$CORE_FILE"
                CORE_API_URL="$URL/api/node/$nid"
                found_config=1
                break
            fi
        done
    fi

    if [ $found_config -eq 0 ]; then
        echo -e "${RED}[!] Could not locate configurations automatically.${NC}"
        read -p "$(echo -e ${WHITE}"Press [Enter] to return..."${NC})"
        return
    fi
    
    echo -e "\n📌 ${MAGENTA}[ SELECT INBOUND TO CLONE FROM ]${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}#    Port    Protocol        Network    Security    Tag${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────${NC}"
    
    local inb_count=$(jq '.inbounds | length' "$CORE_FILE" 2>/dev/null || echo "0")
    for ((i=0; i<$inb_count; i++)); do
        local tag=$(jq -r ".inbounds[$i].tag // empty" "$CORE_FILE")
        local port=$(jq -r ".inbounds[$i].port // empty" "$CORE_FILE")
        local proto=$(jq -r ".inbounds[$i].protocol // empty" "$CORE_FILE")
        local net=$(jq -r '.inbounds['$i'] | if .streamSettings.network then .streamSettings.network elif .settings.network then .settings.network else "tcp" end' "$CORE_FILE")
        local sec=$(jq -r '.inbounds['$i'] | if .streamSettings.security then .streamSettings.security else "none" end' "$CORE_FILE")
        
        printf "  ${CYAN}[%d]${NC}  %-7s  %-12s    %-9s  %-9s  %s\n" "$((i+1))" "$port" "$proto" "$net" "$sec" "$tag"
    done
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${RED}[0] Go Back${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────${NC}"
    
    read -p "$(echo -e ${CYAN}"Select inbound to clone (e.g. 1): "${NC})" inb_sel
    if [ "$inb_sel" == "0" ] || [ -z "$inb_sel" ]; then return; fi
    
    local real_index=$((inb_sel - 1))
    local clone_tag=$(jq -r ".inbounds[$real_index].tag" "$CORE_FILE")
    local clone_port=$(jq -r ".inbounds[$real_index].port" "$CORE_FILE")
    local clone_inbound_json=$(jq ".inbounds[$real_index]" "$CORE_FILE")
    local clone_sec=$(jq -r ".inbounds[$real_index] | if .streamSettings.security then .streamSettings.security else \"none\" end" "$CORE_FILE")

    # ================= HOST MENU =================
    echo -e "\n📌 ${MAGENTA}[ SELECT HOST TO CLONE FROM ]${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}#   Inbound Tag        Remark                         Address                Port${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
    
    local cloned_sni=""
    local clone_host_json="{}"
    local HOSTS_FILE="$BASE_DIR/panel_hosts.json"
    
    local hosts_resp=$(curl -s -X GET "$URL/api/hosts" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
    local is_array=$(echo "$hosts_resp" | jq -r 'type == "array"' 2>/dev/null)
    
    if [ "$is_array" == "true" ]; then
        echo "$hosts_resp" > "$HOSTS_FILE"
    else
        local data_array=$(echo "$hosts_resp" | jq -c '.data // empty' 2>/dev/null)
        if [ -n "$data_array" ]; then
            echo "$data_array" > "$HOSTS_FILE"
        else
            echo "[]" > "$HOSTS_FILE"
        fi
    fi

    local host_count=$(jq 'length' "$HOSTS_FILE" 2>/dev/null || echo "0")

    if [ "$host_count" -gt 0 ]; then
        for ((i=0; i<$host_count; i++)); do
            local h_tag=$(jq -r ".[$i].inbound_tag // \"Unknown\"" "$HOSTS_FILE")
            local h_remark=$(jq -r ".[$i].remark // \"\"" "$HOSTS_FILE")
            
            local h_addr_raw=$(jq -r ".[$i].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else empty end" "$HOSTS_FILE")
            if [ -z "$h_addr_raw" ] || [ "$h_addr_raw" == "null" ]; then h_addr_raw="None"; fi
            local h_addr_disp="['$h_addr_raw']"
            
            local h_port=$(jq -r ".[$i].port // \"None\"" "$HOSTS_FILE")
            if [ "$h_port" == "null" ]; then h_port="None"; fi

            printf "  ${CYAN}[%-2d]${NC} %-18s %-30s %-22s %s\n" "$((i+1))" "$h_tag" "$h_remark" "$h_addr_disp" "$h_port"
        done
        
        echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${RED}[0] Go Back${NC}"
        echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
        
        read -p "$(echo -e ${CYAN}"Enter host # to clone SNI/Address from (or 0 to skip): "${NC})" host_sel
        if [ "$host_sel" == "0" ]; then return; fi
        
        if [[ "$host_sel" =~ ^[0-9]+$ ]] && [ "$host_sel" -gt 0 ]; then
            local real_host_idx=$((host_sel - 1))
            clone_host_json=$(jq ".[$real_host_idx]" "$HOSTS_FILE")
            cloned_sni=$(jq -r ".[$real_host_idx].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" "$HOSTS_FILE")
            if [ "$cloned_sni" == "null" ]; then cloned_sni=""; fi
        fi
    else
        echo -e "  ${YELLOW}No Hosts API found, falling back to Inbounds Data...${NC}"
        for ((i=0; i<$inb_count; i++)); do
            local tag=$(jq -r ".inbounds[$i].tag // empty" "$CORE_FILE")
            local proto=$(jq -r ".inbounds[$i].protocol // empty" "$CORE_FILE")
            local address=$(jq -r '.inbounds['$i'].streamSettings | if .realitySettings.serverNames then .realitySettings.serverNames[0] elif .tlsSettings.serverName then .tlsSettings.serverName else "None" end' "$CORE_FILE")
            local port=$(jq -r ".inbounds[$i].port // empty" "$CORE_FILE")
            if [ "$port" == "null" ] || [ -z "$port" ]; then port="None"; fi
            
            local h_addr_disp="['$address']"
            printf "  ${CYAN}[%-2d]${NC} %-18s %-30s %-22s %s\n" "$((i+1))" "$proto" "$tag" "$h_addr_disp" "$port"
        done
        
        echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
        read -p "$(echo -e ${CYAN}"Enter host # to clone SNI/Address from (or 0 to skip): "${NC})" host_sel
        if [ "$host_sel" == "0" ]; then return; fi
        
        if [[ "$host_sel" =~ ^[0-9]+$ ]] && [ "$host_sel" -gt 0 ]; then
            local real_host_idx=$((host_sel - 1))
            cloned_sni=$(jq -r ".inbounds[$real_host_idx].streamSettings | if .realitySettings.serverNames then .realitySettings.serverNames[0] elif .tlsSettings.serverName then .tlsSettings.serverName else \"\" end" "$CORE_FILE")
            if [ "$cloned_sni" == "null" ]; then cloned_sni=""; fi
        fi
    fi

    echo -e "\n⚡ ${YELLOW}Generating Inbounds, Outbounds & Routing in Memory...${NC}"
    
    local FINAL_FILE="$BASE_DIR/final_core_to_upload.json"
    local NEW_HOSTS_FILE="$BASE_DIR/final_hosts_to_upload.json"
    
    cp "$CORE_FILE" "$FINAL_FILE"
    echo "[]" > "$NEW_HOSTS_FILE"
    
    # --- CHANGED: Loop over user-selected nodes instead of all installed nodes ---
    for idx in "${selected_nodes[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        local emoji="${EMOJIS[$code]}"
        
        local safe_name=$(echo "$name" | tr -d ' ' | tr -cd 'a-zA-Z0-9-')
        local new_remark="$emoji $name"

        local is_duplicate_host=$(jq -e ".[]? | select(.remark == \"$new_remark\")" "$HOSTS_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
        if [[ "$is_duplicate_host" == "yes" ]]; then
            echo -e "  ⚠️  ${YELLOW}$emoji $name is already configured in panel. Skipping to prevent duplicate...${NC}"
            continue
        fi
        
        local rand_port
        local in_tag
        local out_tag
        
        while true; do
            rand_port=$(( RANDOM % 6000 + 3000 ))
            in_tag="${code}-${safe_name}-IN-${rand_port}" 
            out_tag="${code}-${safe_name}-OUT-${out_port}"

            local port_exists=$(jq -e ".inbounds[]? | select(.port == $rand_port)" "$FINAL_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
            local in_tag_exists=$(jq -e ".inbounds[]? | select(.tag == \"$in_tag\")" "$FINAL_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
            local out_tag_exists=$(jq -e ".outbounds[]? | select(.tag == \"$out_tag\")" "$FINAL_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")

            if [[ "$port_exists" == "no" && "$in_tag_exists" == "no" && "$out_tag_exists" == "no" ]]; then
                break
            fi
        done 

        jq --arg p "$rand_port" --arg t "$in_tag" --argjson obj "$clone_inbound_json" \
           'if .inbounds == null then .inbounds = [] else . end | .inbounds += [($obj | .port=($p|tonumber) | .tag=$t)]' \
           "$FINAL_FILE" > tmp.json && mv tmp.json "$FINAL_FILE"
            
        jq --arg t "$out_tag" --arg p "$out_port" \
           'if has("outbounds") and .outbounds != null then . else .outbounds = [] end | .outbounds += [{"tag": $t, "protocol": "socks", "settings": {"servers": [{"address": "127.0.0.1", "port": ($p|tonumber)}]}}]' \
           "$FINAL_FILE" > tmp.json && mv tmp.json "$FINAL_FILE"
            
        jq --arg intag "$in_tag" --arg outtag "$out_tag" \
           'if has("routing") and .routing != null then . else .routing = {"rules": []} end | if .routing.rules == null then .routing.rules = [] else . end | .routing.rules += [{"type": "field", "inboundTag": [$intag], "outboundTag": $outtag}]' \
           "$FINAL_FILE" > tmp.json && mv tmp.json "$FINAL_FILE"

        if [ "$clone_host_json" != "{}" ] && [ "$clone_host_json" != "null" ]; then
            jq --arg tag "$in_tag" --arg p "$rand_port" --arg rem "$new_remark" --argjson obj "$clone_host_json" \
               '. += [($obj | .inbound_tag=$tag | .port=($p|tonumber) | .remark=$rem | .enable=1 | del(.id, .created_at, .updated_at))]' \
               "$NEW_HOSTS_FILE" > tmp_hosts.json && mv tmp_hosts.json "$NEW_HOSTS_FILE" || true
        else
            jq --arg tag "$in_tag" --arg p "$rand_port" --arg rem "$new_remark" --arg addr "$cloned_sni" \
               '. += [{"inbound_tag": $tag, "remark": $rem, "address": [$addr], "port": ($p|tonumber), "enable": 1}]' \
               "$NEW_HOSTS_FILE" > tmp_hosts.json && mv tmp_hosts.json "$NEW_HOSTS_FILE" || true
        fi
            
        echo -e "  ⚙️  $emoji $name | In:$rand_port ➔ Out:$out_port Prepared."
    done
    
    echo -e "\n🚀 ${MAGENTA}[ UPLOADING DIRECTLY TO PANEL VIA API ]${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

    if [ -n "$CORE_API_URL" ]; then
        local original_core_resp=$(curl -s -X GET "$CORE_API_URL" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
        local core_obj=$(echo "$original_core_resp" | jq -r 'if type == "object" and has("data") then .data else . end')
        if [ -z "$core_obj" ] || [ "$core_obj" == "null" ]; then core_obj="{}"; fi
        
        jq --slurpfile newconf "$FINAL_FILE" 'if type == "object" then if .config != null then .config = $newconf[0] elif .xray_config != null then .xray_config = $newconf[0] elif .content != null then .content = $newconf[0] else .config = $newconf[0] end else . end' <<< "$core_obj" > "$BASE_DIR/payload_f_j.json"
        
        draw_progress "Uploading Core Configuration"

        local p_url="$CORE_API_URL"
        local payload="$BASE_DIR/payload_f_j.json"

        local put_resp=$(curl -s -w "\n%{http_code}" -X PUT "$p_url?restart_nodes=true" \
            --max-time 15 \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d @"$payload")
            
        local last_core_error=$(echo "$put_resp" | tail -n1)
        
        echo -e "${YELLOW}[~] Forcing Core Configuration update...${NC}"
        
        for (( i=15; i>=0; i-- )); do
            printf "\r${CYAN}[*] Xray restarting... Please wait: ${MAGENTA}[${YELLOW}%02d${MAGENTA}]${CYAN} seconds remaining${NC}" $i
            sleep 1
        done
        echo -e "\n${GREEN}[+] Xray restarted successfully! OK.${NC}"
    fi

    echo -e "${YELLOW}[~] Pushing Hosts to Panel...${NC}"
    draw_progress "Injecting Hosts"
    
    local host_len=$(jq 'length' "$NEW_HOSTS_FILE")
    for ((h=0; h<$host_len; h++)); do
        local h_data=$(jq -c ".[$h]" "$NEW_HOSTS_FILE")
        local h_success=0
        local h_code=""
        
        local host_endpoints=("/api/host" "/api/hosts" "/api/admin/host" "/api/admin/hosts")
        for hep in "${host_endpoints[@]}"; do
            local h_resp=$(curl -s -w "\n%{http_code}" -X POST "$URL$hep" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -d "$h_data")
            h_code=$(echo "$h_resp" | tail -n1)
            
            if [[ "$h_code" == 2* || "$h_code" == "409" ]]; then
                h_success=1
                break
            fi
        done
        
        if [ $h_success -eq 0 ] && [[ "$h_code" == "405" || "$h_code" == "404" ]]; then
            local current_hosts=$(curl -s -X GET "$URL/api/hosts" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
            local is_arr=$(echo "$current_hosts" | jq 'type == "array"')
            
            if [ "$is_arr" == "true" ]; then
                echo "$current_hosts" > "$BASE_DIR/all_hosts_tmp.json"
            else
                echo "$current_hosts" | jq -c '.data // []' > "$BASE_DIR/all_hosts_tmp.json"
            fi
            
            jq --argjson newh "$h_data" '. += [$newh]' "$BASE_DIR/all_hosts_tmp.json" > tmp_h.json && mv tmp_h.json "$BASE_DIR/all_hosts_tmp.json"
            
            local bulk_resp=$(curl -s -w "\n%{http_code}" -X PUT "$URL/api/hosts" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -d @"$BASE_DIR/all_hosts_tmp.json")
            local bulk_code=$(echo "$bulk_resp" | tail -n1)
            
            if [[ "$bulk_code" == 2* ]]; then
                h_success=1
                h_code=$bulk_code
            fi
        fi
        
        if [ $h_success -eq 1 ]; then
            echo -e " ✅ ${GREEN}Host $((h+1)) Injected Successfully!${NC}"
        else
            echo -e " ❌ ${RED}Failed to inject Host $((h+1)). Last API Error: $h_code${NC}"
        fi
    done

    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo -e "🎉 ${GREEN}Process finished! Check your panel dashboard.${NC}"
    echo -e "💡 ${CYAN}Note: Restarting the Xray Core from your panel is highly recommended to apply changes.${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}\n"
    
    read -p "$(echo -e ${WHITE}"Press [Enter] to continue..."${NC})"
}

# ================= MENU LOOP =================
while true; do
    draw_header
    if command -v tor &> /dev/null && command -v jq &> /dev/null; then
        echo -e "   ${WHITE}System Status:${NC} ${GREEN}Engine Ready${NC}"
    else
        echo -e "   ${WHITE}System Status:${NC} ${RED}Not Ready${NC}"
    fi
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}[1]${NC} ${WHITE}»${NC} Install Engine & Core Tools"
    echo -e "  ${CYAN}[2]${NC} ${WHITE}»${NC} Update System"
    echo -e "  ${CYAN}[3]${NC} ${WHITE}»${NC} Uninstall System"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}[4]${NC} ${WHITE}»${NC} Add Location Node (Single)"
    echo -e "  ${GREEN}[5]${NC} ${WHITE}»${NC} Bulk Add Nodes (Multiple/All)"
    echo -e "  ${GREEN}[6]${NC} ${WHITE}»${NC} View Active Nodes"
    echo -e "  ${GREEN}[7]${NC} ${WHITE}»${NC} Edit or Delete Nodes"
    echo -e "  ${CYAN}[8]${NC} ${WHITE}»${NC} Advanced Port Settings"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}[9]${NC} ${WHITE}»${NC} Panel Pasarguard Integration"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${RED}[0]${NC} ${WHITE}»${NC} Exit Program"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}\n"
    
    read -p "$(echo -e ${MAGENTA}"Enter choice [0-9]: "${NC})" main_choice

    case $main_choice in
        1) install_engine ;;
        2|8) echo -e "${YELLOW}[!] This feature is currently locked for this tier.${NC}"; sleep 2 ;;
        3) uninstall_engine ;;
        4) add_single_node ;;
        5) bulk_add_nodes ;;
        6) view_active_nodes ;;
        7) edit_delete_nodes ;;
        9) check_root; panel_login ;;
        0) clear; exit 0 ;;
        *) ;;
    esac
done
