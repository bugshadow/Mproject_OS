#!/bin/bash

# ==============================================================================
# Fonctions Utilitaires & Core — Partagées entre tous les Devs
# ==============================================================================

# Nettoyage auto en cas d'interruption
cleanup() {
    [ "$FLAG_VERBOSE" = true ] && echo -e "${C_BLUE}[i] Arrêt du script. Nettoyage...${C_RESET}"
}
trap 'cleanup' INT TERM EXIT

# Fonction de journalisation centrale
log_event() {
    local type="$1"   # CMD, SNAP, CORR, DANGER, INFOS, ERROR
    local msg="$2"
    local ts=$(date "+%Y-%m-%d-%H-%M-%S")
    local user_name=${SUDO_USER:-$USER}
    local line="${ts} : ${user_name:-unknown} : ${type} : ${msg}"

    # Affichage coloré sur le terminal
    case "$type" in
        "INFOS")  echo -e "${C_GREEN}[✓] ${msg}${C_RESET}" ;;
        "ERROR")  echo -e "${C_RED}[✗] ${msg}${C_RESET}" >&2 ;;
        "WARN")   echo -e "${C_YELLOW}[!] ${msg}${C_RESET}" ;;
        "DANGER") echo -e "${C_BRED}[⚠] DANGER: ${msg}${C_RESET}" >&2 ;;
        "CMD"|"RET"|"SNAP"|"CORR") 
            [ "$FLAG_VERBOSE" = true ] && echo -e "${C_CYAN}[▶] ${type} : ${msg}${C_RESET}" 
            ;;
        *) echo "$line" ;;
    esac

    # Écriture atomique dans le fichie
    if [ -n "$LOG_FILE" ] && [ -d "$(dirname "$LOG_FILE")" ]; then
        (
            flock -w 2 200
            echo -e "${line}" >> "$LOG_FILE"
        ) 200>>"$LOG_FILE"
    fi
}
export -f log_event

# Fonction d'aide détaillée (avec ASCII art Dev 1)
display_help() {
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║  ██████╗ ██╗      █████╗  ██████╗██╗  ██╗██████╗  ██████╗ ██╗  ██╗  ║
║  ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝  ║
║  ██████╔╝██║     ███████║██║     █████╔╝ ██████╔╝██║   ██║ ╚███╔╝   ║
║  ██╔══██╗██║     ██╔══██║██║     ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗   ║
║  ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗██████╔╝╚██████╔╝██╔╝ ██╗  ║
║  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝  ║
║        Boîte Noire pour Serveurs Linux — v1.0.0                 ║
║        ENSET Mohammedia 2025/2026 — Dev 1 : Core Architecture   ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${C_CYAN}Usage: blackbox [OPTIONS] <SERVICE_NAME>${C_RESET}\n"
    echo "Options:"
    echo "  -h         Affiche cette aide détaillée avec ASCII art"
    echo "  -w         Watch Mode  : surveillance continue (Dev 1 Complet)"
    echo "  -a         Analyze Mode: analyse forensique (Stub Dev 2)"
    echo "  -p         Playback Mode: rejeu de session (Stub Dev 3)"
    echo "  -s         Subshell    : isole dans un sous-shell"
    echo "  -f         Fork        : analyse en parallèle"
    echo "  -t         Thread      : compression multithreadée (Dev 3)"
    echo "  -l <rep>   Log Dir     : répertoire personnalisé history.log"
    echo "  -r         Restore     : reset (root uniquement)"
    echo "  -v         Verbose     : mode débogage"
}

# Gestion fatale des erreurs (Code 100 à 104)
die() {
    local code="$1"
    local message="$2"
    log_event "ERROR" "$message"
    display_help
    exit "$code"
}
