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
    echo -e "${BOLD}Usage:${RESET} plex ${GREEN}{start|stop|reboot|status|logs|update|prune|backup|vpn_status|help}${RESET}"
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
    echo -e "  ${GREEN}help${RESET}         - Show this ${BOLD}help${RESET} message"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

function vpn_status {
    echo -e "${CYAN}Checking VPN connection status for qBittorrent...${RESET}"
    container_ip=$(docker exec qbittorrent curl -s https://ipinfo.io/ip)
    host_ip=$(curl -s https://ipinfo.io/ip)

    echo -e "Container IP: ${GREEN}$container_ip${RESET}"
    echo -e "Host IP: ${YELLOW}$host_ip${RESET}"

    if [ "$container_ip" != "$host_ip" ]; then
        echo -e "${GREEN}VPN is active. qBittorrent is using the VPN connection.${RESET}"
    else
        echo -e "${RED}Warning: qBittorrent is not using the VPN connection!${RESET}"
    fi
}

case "$1" in
    start)
        echo -e "${CYAN}Starting Plex containers...${RESET}"
        docker compose up -d
        ;;
    stop)
        echo -e "${CYAN}Stopping Plex containers...${RESET}"
        docker compose down
        ;;
    reboot)
        echo -e "${CYAN}Restarting Plex containers...${RESET}"
        docker compose down && docker compose up -d
        ;;
    status)
        echo -e "${CYAN}Showing status of Plex containers...${RESET}"
        docker compose ps
        ;;
    logs)
        echo -e "${CYAN}Displaying logs of Plex containers...${RESET}"
        docker compose logs -f
        ;;
    update)
        echo -e "${CYAN}Updating Docker images and restarting containers...${RESET}"
        docker compose pull && docker compose down && docker compose up -d
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
    *)
        echo -e "${RED}Unknown command:${RESET} $1"
        show_help
        exit 1
        ;;
esac
