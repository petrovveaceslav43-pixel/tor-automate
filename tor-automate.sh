#!/usr/bin/env bash
# Tor Automate Engine V1.8
# Inbound/Outbound Port Mapping & Persistence (Fixed with Socat Forwarding)

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
GOLD='\033[38;5;220m'
BG_BLUE='\033[44m'

# ================= CONFIG =================
BASE_DIR="/etc/tor/t_sin_nodes"
DATA_DIR="/var/lib/tor/t_sin_nodes"

# Format: "CountryCode : CountryName : InboundPort(Xray/Panel) : OutboundPort(Tor) : Tier"
declare -A NODES=(
    [01]="DE:Germany:3031:9080:Standard" [02]="TR:Turkey:3032:9081:Standard" [03]="US:United States:3033:9082:Standard"
    [04]="FR:France:3034:9083:Standard" [05]="AT:Austria:3035:9084:Standard" [06]="BE:Belgium:3036:9085:Standard"
    [07]="RO:Romania:3037:9086:Standard" [08]="CA:Canada:3038:9087:Standard" [09]="SG:Singapore:3039:9088:Standard"
    [10]="JP:Japan:3040:9089:Standard" [11]="IE:Ireland:3041:9090:Standard" [12]="FI:Finland:3042:9091:Standard"
    [13]="ES:Spain:3043:9092:Standard" [14]="PL:Poland:3044:9093:Standard" [15]="NL:Netherlands:3045:9094:Standard"
    [16]="IT:Italy:3046:9095:Gold" [17]="CH:Switzerland:3047:9096:Gold" [18]="SE:Sweden:3048:9097:Gold"
    [19]="NO:Norway:3049:9098:Gold" [20]="DK:Denmark:3050:9099:Gold" [21]="IS:Iceland:3051:9100:Gold"
    [22]="AU:Australia:3052:9101:Gold" [23]="IN:India:3053:9102:Gold" [24]="HK:Hong Kong:3054:9103:Gold"
    [25]="UA:Ukraine:3055:9104:Gold" [26]="CZ:Czech Republic:3056:9105:Gold" [27]="KR:South Korea:3057:9106:Gold"
    [28]="ZA:South Africa:3058:9107:Gold" [29]="MX:Mexico:3059:9108:Gold" [30]="MY:Malaysia:3060:9109:Gold"
    [31]="AZ:Azerbaijan:3061:9110:Gold" [32]="CY:Cyprus:3062:9111:Gold" [33]="GR:Greece:3063:9112:Gold"
    [34]="PT:Portugal:3064:9113:Gold" [35]="HU:Hungary:3065:9114:Gold" [36]="LU:Luxembourg:3066:9115:Gold"
    [37]="GB:United Kingdom:3067:9116:Gold" [38]="AR:Argentina:3068:9117:Gold" [39]="TW:Taiwan:3069:9118:Gold"
    [40]="BG:Bulgaria:3070:9119:Gold" [41]="IL:Israel:3071:9120:Gold" [42]="MD:Moldova:3072:9121:Gold"
    [43]="RU:Russia:3073:9122:Gold" [44]="CL:Chile:3074:9123:Gold" [45]="CR:Costa Rica:3075:9124:Gold"
    [46]="VN:Vietnam:3076:9125:Gold" [47]="ID:Indonesia:3077:9126:Gold" [48]="SC:Seychelles:3078:9127:Gold"
    [49]="HR:Croatia:3079:9128:Gold" [50]="TN:Tunisia:3080:9129:Gold"
)

ORDER=({01..50})

# ================= UI FUNCTIONS =================

draw_header() {
    clear
    echo -e "${MAGENTA} ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA} ║${CYAN}  ████████╗ ██████╗ ██████╗                             ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}  ╚══██╔══╝██╔═══██╗██╔══██╗                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ██║   ██║██████╔╝                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ██║   ██║██╔══██╗                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ██║   ╚██████╔╝██║  ██║                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}     ╚═╝    ╚═════╝ ╚═╝  ╚═╝                            ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${YELLOW}        A U T O M A T E   E N G I N E   V1.8            ${MAGENTA}║${NC}"
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
    local code=$1; local name=$2; local in_port=$3; local out_port=$4; local attempt=1; local max_attempts=2
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local inst_data_dir="$DATA_DIR/${code}_${out_port}"
    local ip_file="$inst_data_dir/last_ip.txt"

    # پیش‌نیاز فوروارد پورت
    if ! command -v socat &> /dev/null; then
        echo -e "${YELLOW}[*] Installing 'socat' for port forwarding...${NC}"
        apt-get update -y > /dev/null 2>&1
        apt-get install -y socat > /dev/null 2>&1
    fi

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

    # از بین بردن پراسس‌های قبلی همین نود (هم تور و هم فوروارد پورت)
    if pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
        pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
    fi
    if pgrep -f "socat TCP4-LISTEN:$in_port" > /dev/null; then
        pkill -f "socat TCP4-LISTEN:$in_port" 2>/dev/null || true
    fi

    echo -e "${CYAN}[*] Routing ${WHITE}$name ${CYAN}| Xray Port: ${YELLOW}$in_port ${CYAN}➔ Tor Port: ${MAGENTA}$out_port${CYAN}. Please wait...${NC}"
    
    # 1. اجرای Tor
    sudo -u debian-tor tor -f "$conf_file" >/dev/null 2>&1 &
    
    # 2. ایجاد تونل فورواردینگ با Socat (اتصال Xray به Tor)
    socat TCP4-LISTEN:$in_port,reuseaddr,fork TCP4:127.0.0.1:$out_port &
    
    draw_progress "Bootstrapping tunnel connection"

    while [ $attempt -le $max_attempts ]; do
        local public_ip=$(curl -s --socks5-hostname 127.0.0.1:$out_port https://api.ipify.org --max-time 8 || true)
        if [ ! -z "$public_ip" ] && [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$public_ip" > "$ip_file"
            echo -e "${GREEN}[+] Online -> ${WHITE}$name ${GREEN}($public_ip)${NC}"
            echo -e "${CYAN}[*] Action: In your Xray panel, set the proxy port to -> ${YELLOW}$in_port${NC}\n"
            return 0
        fi
        
        echo -e "${YELLOW}[*] Re-routing node (Attempt $attempt/$max_attempts)...${NC}"
        pkill -HUP -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        attempt=$((attempt+1))
        sleep 3
    done
    echo -e "${RED}[-] Setup failed or Country restricted for $name${NC}\n"
}

list_locations() {
    echo -e "${YELLOW}Available Locations:${NC}"
    echo -e "${MAGENTA}Format: ${CYAN}[Code] [Xray Port ➔ Tor Port] - Country${NC}\n"
    for idx in "${ORDER[@]}"; do
        local details="${NODES[$idx]}"
        IFS=':' read -r code name in_port out_port tier <<< "$details"
        if [ "$tier" == "Gold" ]; then
            printf "  ${CYAN}%s${NC} - [${WHITE}%s${NC}] [${YELLOW}%s${NC} ➔ ${MAGENTA}%s${NC}] - %-20s ${GOLD}★ [Gold]${NC}\n" "$idx" "$code" "$in_port" "$out_port" "$name"
        else
            printf "  ${CYAN}%s${NC} - [${WHITE}%s${NC}] [${YELLOW}%s${NC} ➔ ${MAGENTA}%s${NC}] - %s\n" "$idx" "$code" "$in_port" "$out_port" "$name"
        fi
    done
    echo -e "\n  ${RED}00${NC} - ${WHITE}Back to main menu${NC}\n"
}

view_active_nodes() {
    draw_header
    echo -e "${CYAN}» Option 6 - View Active Nodes (Persistent Tracking)${NC}\n"
    echo -e "${YELLOW}[*] Probing RAM and Storage for deployed systems...${NC}"
    echo -e "${BLUE}┌──────┬──────────────────────┬──────────────────────┬────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE} ID   ${BLUE}│${WHITE} Location             ${BLUE}│${WHITE} Xray Port ➔ Tor Port ${BLUE}│${WHITE} Live IP / Last IP          ${BLUE}│${NC}"
    echo -e "${BLUE}├──────┼──────────────────────┼──────────────────────┼────────────────────────────┤${NC}"
    
    local found=0
    for idx in "${ORDER[@]}"; do
        local details="${NODES[$idx]}"
        IFS=':' read -r code name in_port out_port tier <<< "$details"
        
        local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
        local ip_file="$DATA_DIR/${code}_${out_port}/last_ip.txt"
        
        if [ -f "$conf_file" ]; then
            found=1
            local route_str="${in_port} ➔ ${out_port}"
            printf "${BLUE}│${CYAN} %-4s ${BLUE}│${WHITE} %-20s ${BLUE}│${YELLOW} %-20s ${BLUE}│ " "$idx" "$name" "$route_str"
            
            if pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
                local ip=$(curl -s --socks5-hostname 127.0.0.1:$out_port https://api.ipify.org --max-time 3 || true)
                
                if [ ! -z "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    echo "$ip" > "$ip_file"
                    printf "${GREEN}%-26s${BLUE}│${NC}\n" "$ip"
                else
                    if [ -f "$ip_file" ]; then
                        local cached_ip=$(cat "$ip_file")
                        printf "${YELLOW}%-26s${BLUE}│${NC}\n" "$cached_ip (Cached)"
                    else
                        printf "${YELLOW}%-26s${BLUE}│${NC}\n" "Connecting..."
                    fi
                fi
            else
                if [ -f "$ip_file" ]; then
                    local stopped_ip=$(cat "$ip_file")
                    printf "${RED}%-26s${BLUE}│${NC}\n" "$stopped_ip (Stopped)"
                else
                    printf "${RED}%-26s${BLUE}│${NC}\n" "Offline/Crashed"
                fi
            fi
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo -e "${BLUE}│${YELLOW} No active nodes found in the system.                                         ${BLUE}│${NC}"
    fi
    echo -e "${BLUE}└──────┴──────────────────────┴──────────────────────┴────────────────────────────┘${NC}\n"
    read -p "$(echo -e ${WHITE}"Press Enter to return to main menu..."${NC})"
}

edit_delete_nodes() {
    draw_header
    echo -e "${CYAN}» Option 7 - Edit or Delete Nodes${NC}\n"
    echo -e "${YELLOW}Installed Nodes:${NC}"
    
    local installed=()
    for idx in "${ORDER[@]}"; do
        local details="${NODES[$idx]}"
        IFS=':' read -r code name in_port out_port tier <<< "$details"
        if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
            printf "  ${CYAN}%s${NC} - ${WHITE}%s${NC} [Xray: ${YELLOW}%s${NC} ➔ Tor: ${MAGENTA}%s${NC}]\n" "$idx" "$name" "$in_port" "$out_port"
            installed+=("$idx")
        fi
    done
    
    echo -e "\n  ${RED}00${NC} - ${WHITE}Back to main menu${NC}\n"
    
    if [ ${#installed[@]} -eq 0 ]; then
        echo -e "${YELLOW}[!] No nodes are currently installed.${NC}"
        read -p "$(echo -e ${WHITE}"Press Enter to return..."${NC})"
        return
    fi

    read -p "$(echo -e ${CYAN}"Select node index to manage (delete): "${NC})" raw_del_idx
    if [ -z "$raw_del_idx" ] || [ "$raw_del_idx" == "00" ] || [ "$raw_del_idx" == "0" ]; then return; fi
    
    local cleaned_idx=$(echo "$raw_del_idx" | sed 's/^0*//')
    local del_idx=$(printf "%02d" "$cleaned_idx")

    if [[ " ${installed[*]} " =~ " ${del_idx} " ]]; then
        local details="${NODES[$del_idx]}"
        IFS=':' read -r code name in_port out_port tier <<< "$details"
        
        # Kill both Tor and the Port Forwarding bridge
        pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        pkill -f "socat TCP4-LISTEN:$in_port" 2>/dev/null || true
        
        rm -f "$BASE_DIR/node_${code}_${out_port}.conf"
        rm -rf "$DATA_DIR/${code}_${out_port}"
        
        echo -e "${GREEN}[+] Node ${WHITE}$name${GREEN} and its forwarding port (${YELLOW}$in_port${GREEN}) have been successfully removed.${NC}"
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
        echo -e "${YELLOW}[!] Initiating deployment for ALL available nodes...${NC}"
        for idx in "${ORDER[@]}"; do
            IFS=':' read -r code name in_port out_port tier <<< "${NODES[$idx]}"
            echo -e "\n${CYAN}[*] Processing ${WHITE}$name${CYAN}...${NC}"
            deploy_node "$code" "$name" "$in_port" "$out_port"
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
                    IFS=':' read -r code name in_port out_port tier <<< "${NODES[$p_idx]}"
                    echo -e "\n${CYAN}[*] Processing ${WHITE}$name${CYAN}...${NC}"
                    deploy_node "$code" "$name" "$in_port" "$out_port"
                    sleep 1
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
    echo -e "  ${GOLD}[9]${NC} ${WHITE}»${NC} EZ-Panel Integration"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${RED}[0]${NC} ${WHITE}»${NC} Exit Program"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}\n"
    
    read -p "$(echo -e ${MAGENTA}"Enter choice [0-9]: "${NC})" main_choice

    case $main_choice in
        1) check_root; echo -e "${CYAN}[*] Install Logic Goes Here...${NC}"; sleep 1 ;;
        2|3|8|9) echo -e "${YELLOW}[!] This feature is currently locked for this tier.${NC}"; sleep 2 ;;
        4)
            check_root; draw_header; echo -e "${CYAN}» Option 4 - Add Location Node${NC}\n"; list_locations
            read -p "$(echo -e ${MAGENTA}"Select location index: "${NC})" loc_idx
            if [[ "$loc_idx" == "00" ]]; then continue; fi
            p_idx=$(printf "%02d" "$loc_idx")
            if [[ -n "${NODES[$p_idx]}" ]]; then
                IFS=':' read -r code name in_port out_port tier <<< "${NODES[$p_idx]}"
                deploy_node "$code" "$name" "$in_port" "$out_port"
                read -p "$(echo -e ${WHITE}"Press Enter to return..."${NC})"
            fi
            ;;
        5) check_root; bulk_add_nodes ;;
        6) view_active_nodes ;;
        7) check_root; edit_delete_nodes ;;
        0) clear; exit 0 ;;
        *) ;;
    esac
done