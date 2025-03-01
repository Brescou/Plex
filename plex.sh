#!/bin/bash

cd ~/Plex || exit

BOLD="\033[1m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

function show_help {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}             Plex Management Script${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}Usage:${RESET} plex ${GREEN}{start|stop|reboot|status|logs|update|prune|backup|vpn_status|help}${RESET} [profile]"
    echo
    echo -e "${YELLOW}Commands:${RESET}"
    echo -e "  ${GREEN}start${RESET}        - ${BOLD}Start${RESET} Plex containers in the background"
    echo -e "  ${GREEN}stop${RESET}         - ${BOLD}Stop${RESET} all Plex containers"
    echo -e "  ${GREEN}reboot${RESET}       - ${BOLD}Restart${RESET} Plex containers"
    echo -e "  ${GREEN}status${RESET}       - Show the ${BOLD}status${RESET} of Plex containers"
    echo -e "  ${GREEN}logs${RESET}         - Display ${BOLD}real-time logs${RESET} of Plex containers"
    echo -e "  ${GREEN}update${RESET}       - ${BOLD}Pull the latest images${RESET} and restart containers"
    echo -e "  ${GREEN}prune${RESET}        - ${BOLD}Clean up${RESET} unused Docker resources"
    echo -e "  ${GREEN}backup${RESET}       - ${BOLD}Backup${RESET} Plex configuration"
    echo -e "  ${GREEN}vpn_status${RESET}   - Check if ${BOLD}qBittorrent is routed through the VPN${RESET}"
    echo -e "  ${GREEN}switch${RESET}       - ${BOLD}Switch${RESET} to a different profile (stops all containers first)"
    echo -e "  ${GREEN}help${RESET}         - Show this ${BOLD}help${RESET} message"
    echo -e "  ${GREEN}active${RESET}       - Show ${BOLD}currently active${RESET} containers and their profiles"
    echo
    echo -e "${YELLOW}Profiles:${RESET}"
    echo -e "  ${GREEN}plex${RESET}         - Only Plex server"
    echo -e "  ${GREEN}torrent${RESET}      - Only torrent-related services"
    echo -e "  ${GREEN}all${RESET}          - All services (default)"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

function vpn_status {
    echo -e "${CYAN}Checking VPN connection status for all containers...${RESET}"

    # Vérifier l'IP de l'hôte
    host_ip=$(curl -s https://ipinfo.io/ip)
    host_location=$(curl -s "https://ipinfo.io/$host_ip" | jq -r '.city, .region, .country' | paste -sd ", " -)
    echo -e "${BOLD}Host:${RESET}"
    echo -e "  - IP: ${YELLOW}$host_ip${RESET}"
    echo -e "  - Location: ${GREEN}$host_location${RESET}\n"

    # Vérifier l'IP via Deluge
    echo -e "${BOLD}VPN Status (via Deluge):${RESET}"
    if docker ps --format '{{.Names}}' | grep -q "^deluge$"; then
        # Installer curl si nécessaire et vérifier l'IP
        docker exec deluge apt-get update >/dev/null 2>&1
        docker exec deluge apt-get install -y curl >/dev/null 2>&1
        vpn_ip=$(docker exec deluge curl -s https://ipinfo.io/ip)
        if [ -n "$vpn_ip" ]; then
            vpn_location=$(curl -s "https://ipinfo.io/$vpn_ip" | jq -r '.city, .region, .country' | paste -sd ", " -)
            echo -e "  - IP: ${GREEN}$vpn_ip${RESET}"
            echo -e "  - Location: ${GREEN}$vpn_location${RESET}\n"
        else
            echo -e "  - ${RED}Unable to retrieve IP${RESET}\n"
        fi
    else
        echo -e "  - ${RED}Deluge container not running${RESET}\n"
    fi

    # Liste des containers qui devraient utiliser le VPN
    echo -e "${BOLD}Containers using gluetun network:${RESET}"
    vpn_containers=("deluge" "jackett" "sonarr" "radarr" "flaresolverr")
    for container in "${vpn_containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "  - ${container}: ${GREEN}Using gluetun network${RESET}"
        else
            echo -e "  - ${container}: ${RED}Not running${RESET}"
        fi
    done
}


function show_active {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}Active Containers and Profiles${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Vérifier Plex
    if docker ps --format '{{.Names}}' | grep -q "^plex$"; then
        echo -e "${YELLOW}Profile: plex${RESET}"
        echo -e "  - ${GREEN}plex${RESET} is running"
        echo
    fi

    # Vérifier les services torrent
    TORRENT_SERVICES=("gluetun" "qbittorrent" "jackett" "sonarr" "radarr" "flaresolverr")
    FOUND_TORRENT=false
    
    for service in "${TORRENT_SERVICES[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
            if [ "$FOUND_TORRENT" = false ]; then
                echo -e "${YELLOW}Profile: torrent${RESET}"
                FOUND_TORRENT=true
            fi
            echo -e "  - ${GREEN}${service}${RESET} is running"
        fi
    done
    
    if [ "$FOUND_TORRENT" = true ]; then
        echo
    fi

    # Afficher le nombre total de conteneurs actifs
    TOTAL_ACTIVE=$(docker ps --format '{{.Names}}' | wc -l)
    echo -e "${BOLD}Total active containers:${RESET} ${GREEN}${TOTAL_ACTIVE}${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

function get_active_profile {
    if docker ps --format '{{.Names}}' | grep -q "^plex$"; then
        if docker ps --format '{{.Names}}' | grep -q "^gluetun$"; then
            echo "all"
        else
            echo "plex"
        fi
    elif docker ps --format '{{.Names}}' | grep -q "^gluetun$"; then
        echo "torrent"
    else
        echo "none"
    fi
}

function stop_all_containers {
    echo -e "${CYAN}Stopping all running containers...${RESET}"
    
    # Arrêter d'abord les conteneurs qui dépendent d'autres conteneurs
    for container in flaresolverr qbittorrent jackett sonarr radarr; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "Stopping ${YELLOW}${container}${RESET}..."
            docker stop ${container} >/dev/null 2>&1
        fi
    done
    
    # Arrêter gluetun
    if docker ps --format '{{.Names}}' | grep -q "^gluetun$"; then
        echo -e "Stopping ${YELLOW}gluetun${RESET}..."
        docker stop gluetun >/dev/null 2>&1
    fi
    
    # Arrêter Plex en dernier
    if docker ps --format '{{.Names}}' | grep -q "^plex$"; then
        echo -e "Stopping ${YELLOW}plex${RESET}..."
        docker stop plex >/dev/null 2>&1
    fi
    
    # S'assurer que tous les conteneurs sont arrêtés
    docker compose down --remove-orphans
}

# Get the profile argument or default to "all"
PROFILE=${2:-all}
PROFILE_CMD="--profile $PROFILE"

case "$1" in
    start)
        echo -e "${CYAN}Stopping any running containers first...${RESET}"
        docker compose down
        echo -e "${CYAN}Starting Plex containers (Profile: $PROFILE)...${RESET}"
        docker compose $PROFILE_CMD up -d
        ;;
    stop)
        stop_all_containers
        ;;
    switch)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please specify a profile to switch to (plex|torrent|all)${RESET}"
            exit 1
        fi
        
        CURRENT_PROFILE=$(get_active_profile)
        
        if [ "$CURRENT_PROFILE" = "$PROFILE" ]; then
            echo -e "${YELLOW}Profile $PROFILE is already active${RESET}"
            exit 0
        fi
        
        echo -e "${CYAN}Current profile: $CURRENT_PROFILE${RESET}"
        echo -e "${CYAN}Switching to profile: $PROFILE${RESET}"
        
        stop_all_containers
        
        echo -e "${CYAN}Starting new profile ($PROFILE)...${RESET}"
        docker compose $PROFILE_CMD up -d
        ;;
    reboot)
        echo -e "${CYAN}Restarting Plex containers (Profile: $PROFILE)...${RESET}"
        docker compose $PROFILE_CMD down && docker compose $PROFILE_CMD up -d
        ;;
    status)
        echo -e "${CYAN}Showing status of Plex containers (Profile: $PROFILE)...${RESET}"
        docker compose $PROFILE_CMD ps
        ;;
    logs)
        echo -e "${CYAN}Displaying logs of Plex containers (Profile: $PROFILE)...${RESET}"
        docker compose $PROFILE_CMD logs -f
        ;;
    update)
        echo -e "${CYAN}Updating Docker images and restarting containers (Profile: $PROFILE)...${RESET}"
        docker compose $PROFILE_CMD pull && docker compose $PROFILE_CMD down && docker compose $PROFILE_CMD up -d
        ;;
    prune)
        echo -e "${CYAN}Cleaning up unused Docker resources...${RESET}"
        docker system prune -f
        ;;
    backup)
        echo -e "${CYAN}Backing up Plex configuration...${RESET}"
        mkdir -p ~/Plex/backup
        cp -r ~/Plex/database ~/Plex/backup/database_$(date +%F_%T)
        echo -e "${GREEN}Backup completed.${RESET}"
        ;;
    vpn_status)
        vpn_status
        ;;
    help|--help|-h)
        show_help
        ;;
    active)
        show_active
        ;;
    *)
        echo -e "${RED}Unknown command:${RESET} $1"
        show_help
        exit 1
        ;;
esac
