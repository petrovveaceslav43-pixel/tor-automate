#!/usr/bin/env bash
# Tor Automate Engine V2.0
# Outbound Port Mapping & Persistence (Tor Only) - Clean UI & Live Monitor

set -e

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

ORDER=({01..50})

# ================= UI FUNCTIONS =================

draw_header() {
    clear
    echo -e "${MAGENTA} ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA} ║${CYAN}  ████████╗ ██████╗ ██████╗                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}  ╚══██╔══╝██╔═══██╗██╔══██╗                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ██║   ██║██████╔╝                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ██║   ██║██╔══██╗                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ╚██████╔╝██║  ██║                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ╚═╝    ╚═════╝ ╚═╝  ╚═╝                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${YELLOW}      A U T O M A T E   E N G I N E   V2.0            ${MAGENTA}║${NC}"
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

# ================= CORE FUNCTIONS =================

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}[!] Error: Please run as root (sudo).${NC}"
        exit 1
    fi
}

deploy_node() {
    local code=$1; local name=$2; local out_port=$3; local attempt=1; local max_attempts=2
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
    chown debian-tor:debian-tor "$conf_file"

    if pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
        pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
    fi

    echo -e "${CYAN}[*] Routing ${WHITE}$code - $name ${CYAN}➔ Tor Port: ${MAGENTA}$out_port${CYAN}. Please wait...${NC}"
    
    sudo -u debian-tor tor -f "$conf_file" >/dev/null 2>&1 &
    
    draw_progress "Bootstrapping Tor connection"

    while [ $attempt -le $max_attempts ]; do
        local public_ip=$(curl -s --socks5-hostname 127.0.0.1:$out_port https://api.ipify.org --max-time 8 || true)
        if [ ! -z "$public_ip" ] && [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$public_ip" > "$ip_file"
            echo -e "${GREEN}[+] Online -> ${WHITE}$code - $name ${GREEN}($public_ip)${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}[*] Re-routing node (Attempt $attempt/$max_attempts)...${NC}"
        pkill -HUP -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        attempt=$((attempt+1))
        sleep 3
    done
    echo -e "${RED}[-] Setup failed or Country restricted for $code - $name${NC}\n"
}

list_locations() {
    echo -e "${YELLOW}Available Locations:${NC}\n"
    
    # تنظیم رنگ‌ها
    local C_CYAN='\033[1;36m'
    local C_GREEN='\033[1;32m'
    local C_WHITE='\033[1;37m'
    local NC='\033[0m'
    
    local CIRCLE_ON="${C_GREEN}●${NC}"
    local CIRCLE_OFF="${C_WHITE}○${NC}"
    
    for ((i=1; i<=25; i++)); do
        local idx1=$(printf "%02d" $i)
        local idx2=$(printf "%02d" $((i+25)))
        
        # --- آماده‌سازی ستون چپ ---
        IFS=':' read -r code1 name1 port1 <<< "${NODES[$idx1]}"
        local stat1="$CIRCLE_OFF"
        if [ -f "$BASE_DIR/node_${code1}_${port1}.conf" ]; then
            stat1="$CIRCLE_ON"
        fi
        
        # --- آماده‌سازی ستون راست ---
        local col2_str=""
        if [[ -n "${NODES[$idx2]}" ]]; then
            IFS=':' read -r code2 name2 port2 <<< "${NODES[$idx2]}"
            local stat2="$CIRCLE_OFF"
            if [ -f "$BASE_DIR/node_${code2}_${port2}.conf" ]; then
                stat2="$CIRCLE_ON"
            fi
            # چیدمان ستون دوم: [ID] Circle Name
            col2_str=$(printf "${C_CYAN}[%s]${NC} %b %-16s" "$idx2" "$stat2" "$name2")
        fi
        
        # چاپ نهایی (ستون اول: [ID] Circle Name)
        printf "  ${C_CYAN}[%s]${NC} %b %-16s    %b\n" "$idx1" "$stat1" "$name1" "$col2_str"
    done
    
    echo -e "\n  ${RED}00${NC} - ${WHITE}Back to main menu${NC}\n"
}

view_active_nodes() {
    while true; do
        draw_header
        echo -e "${CYAN}» Option 6 - Active Nodes Monitor (Instant Auto-Heal)${NC}"
        echo -e "${YELLOW}[*] Live monitoring... Dead nodes will be restarted instantly.${NC}\n"
        
        echo -e "${BLUE}┌──────┬──────┬──────────────────────┬─────────────┬──────────────┬────────────────────────────┐${NC}"
        echo -e "${BLUE}│${WHITE} ID   ${BLUE}│${WHITE} CC   ${BLUE}│${WHITE} Location             ${BLUE}│${WHITE} Tor Port    ${BLUE}│${WHITE} Status       ${BLUE}│${WHITE} Live IP                    ${BLUE}│${NC}"
        echo -e "${BLUE}├──────┼──────┼──────────────────────┼─────────────┼──────────────┼────────────────────────────┤${NC}"
        
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
                    printf "${BLUE}│ ${CYAN}%-4s ${BLUE}│ ${WHITE}%-4s ${BLUE}│ ${WHITE}%-20s ${BLUE}│ ${MAGENTA}%-11s ${BLUE}│ ${GREEN}%-12s ${BLUE}│ ${GREEN}%-26s ${BLUE}│${NC}\n" "$idx" "$code" "$name" "$out_port" "ONLINE" "$display_ip"
                else
                    rm -f "$ip_file"
                    sudo -u debian-tor tor -f "$conf_file" >/dev/null 2>&1 &
                    
                    printf "${BLUE}│ ${CYAN}%-4s ${BLUE}│ ${WHITE}%-4s ${BLUE}│ ${WHITE}%-20s ${BLUE}│ ${MAGENTA}%-11s ${BLUE}│ ${YELLOW}%-12s ${BLUE}│ ${YELLOW}%-26s ${BLUE}│${NC}\n" "$idx" "$code" "$name" "$out_port" "HEALING..." "Restarting..."
                    
                    (
                        sleep 8
                        local new_ip=$(curl -s --socks5-hostname 127.0.0.1:$out_port https://api.ipify.org --max-time 15 || true)
                        if [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                            echo "$new_ip" > "$ip_file"
                        fi
                    ) &
                fi
            fi
        done
        
        if [ $found -eq 0 ]; then
            printf "${BLUE}│ ${YELLOW}%-90s ${BLUE}│${NC}\n" "No active nodes found in the system."
        fi
        echo -e "${BLUE}└──────┴──────┴──────────────────────┴─────────────┴──────────────┴────────────────────────────┘${NC}\n"
        
        echo -e "${MAGENTA}[ Live Monitoring Active ]${NC} Screen refreshes every 3 seconds."
        echo -e "${WHITE}Press any key (or Enter) to stop monitoring and return to main menu...${NC}"
        
        if read -t 3 -n 1 -s key; then
            break
        fi
    done
}

edit_delete_nodes() {
    draw_header
    echo -e "${CYAN}» Option 7 - Edit or Delete Nodes${NC}\n"
    echo -e "${YELLOW}Installed Nodes:${NC}"
    
    local installed=()
    for idx in "${ORDER[@]}"; do
        local details="${NODES[$idx]}"
        IFS=':' read -r code name out_port <<< "$details"
        if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
            printf "  ${CYAN}%s${NC} - ${WHITE}%s - %s${NC} \e[1;32m✔\e[0m [Tor: ${MAGENTA}%s${NC}]\n" "$idx" "$code" "$name" "$out_port"
            installed+=("$idx")
        fi
    done
    
    echo -e "\n  ${RED}99${NC} - ${RED}Delete ALL Nodes${NC}"
    echo -e "  ${RED}00${NC} - ${WHITE}Back to main menu${NC}\n"
    
    if [ ${#installed[@]} -eq 0 ]; then
        echo -e "${YELLOW}[!] No nodes are currently installed.${NC}"
        read -p "$(echo -e ${WHITE}"Press Enter to return..."${NC})"
        return
    fi

    read -p "$(echo -e ${CYAN}"Select node index to manage (delete): "${NC})" raw_del_idx
    if [ -z "$raw_del_idx" ] || [ "$raw_del_idx" == "00" ] || [ "$raw_del_idx" == "0" ]; then return; fi
    
    if [ "$raw_del_idx" == "99" ]; then
        echo -e "${YELLOW}[*] Deleting ALL nodes...${NC}"
        pkill -f "t_sin_nodes/node_" 2>/dev/null || true
        rm -rf "$BASE_DIR"/*
        rm -rf "$DATA_DIR"/*
        echo -e "${GREEN}[+] All nodes have been successfully removed.${NC}"
        sleep 2
        return
    fi
    
    local cleaned_idx=$(echo "$raw_del_idx" | sed 's/^0*//')
    local del_idx=$(printf "%02d" "$cleaned_idx")

    if [[ " ${installed[*]} " =~ " ${del_idx} " ]]; then
        local details="${NODES[$del_idx]}"
        IFS=':' read -r code name out_port <<< "$details"
        
        pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        
        rm -f "$BASE_DIR/node_${code}_${out_port}.conf"
        rm -rf "$DATA_DIR/${code}_${out_port}"
        
        echo -e "${GREEN}[+] Node ${WHITE}$code - $name${GREEN} (Tor Port: ${MAGENTA}$out_port${GREEN}) has been successfully removed.${NC}"
        sleep 2
    else
        echo -e "${RED}[!] Invalid index or node not installed.${NC}"
        sleep 2
    fi
}

bulk_add_nodes() {
    draw_header
    echo -e "${CYAN}» Option 5 - Bulk Add Nodes${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Deploy All Supported Locations (Full World)"
    echo -e "  ${GREEN}[2]${NC} Custom Batch Deployment (Comma separated selection)"
    echo -e "  ${RED}[0]${NC} Go Back\n"
    
    read -p "$(echo -e ${CYAN}"Select deployment mode [0-2]: "${NC})" bulk_opt
    
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
    fi
}

# ================= MENU LOOP =================
while true; do
    draw_header
    if command -v tor &> /dev/null; then
        echo -e "   ${WHITE}System Status:${NC} ${GREEN}Engine Installed & Ready ✔${NC}"
    else
        echo -e "   ${WHITE}System Status:${NC} ${RED}Not Installed ✘${NC}"
    fi
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}[1]${NC} ${WHITE}»${NC} Install Engine & Core Tools"
    echo -e "  ${CYAN}[2]${NC} ${WHITE}»${NC} Update System"
    echo -e "  ${CYAN}[3]${NC} ${WHITE}»${NC} Uninstall System"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}[4]${NC} ${WHITE}»${NC} Add Location Node"
    echo -e "  ${GREEN}[5]${NC} ${WHITE}»${NC} Bulk Add Nodes"
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
        1) check_root; echo -e "${CYAN}[*] Install Logic Goes Here...${NC}"; sleep 1 ;;
        2|8) echo -e "${YELLOW}[!] This feature is currently locked for this tier.${NC}"; sleep 2 ;;
        3) 
            check_root
            echo -e "${YELLOW}[*] Uninstalling Tor Automate Engine completely...${NC}"
            pkill -f "t_sin_nodes/node_" 2>/dev/null || true
            rm -rf /etc/tor/t_sin_nodes
            rm -rf /var/lib/tor/t_sin_nodes
            rm -f /usr/local/bin/tor-automate
            echo -e "${GREEN}[+] Uninstallation complete. The program has been removed.${NC}"
            exit 0
            ;;
        4)
            check_root; draw_header; echo -e "${CYAN}» Option 4 - Add Location Node${NC}\n"; list_locations
            read -p "$(echo -e ${MAGENTA}"Select location index: "${NC})" loc_idx
            if [[ "$loc_idx" == "00" ]]; then continue; fi
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
            ;;
        5) check_root; bulk_add_nodes ;;
        6) view_active_nodes ;;
        7) check_root; edit_delete_nodes ;;
        9) echo -e "${YELLOW}[!] This feature is currently locked for this tier.${NC}"; sleep 2 ;;
        0) clear; exit 0 ;;
        *) ;;
    esac
done
