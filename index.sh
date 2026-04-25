#!/bin/bash

# ============================================
# BLACKBOX - Boîte Noire pour Serveurs Linux
# ============================================

# ── Variables globales (partagees par tous) ──

LOG_DIR="/var/log/blackbox"
LOG_FILE="$LOG_DIR/history.log"
ARCHIVE_DIR="$LOG_DIR/archives"
SERVICE_NAME=""
MODE=""
FLAG_SUBSHELL=false
FLAG_FORK=false
FLAG_THREAD=false
FLAG_VERBOSE=false
CUSTOM_LOG_DIR=""

# ── Fonction log centrale (Dev 2 et Dev 3 l'utilisent aussi) ──
log_event() {
    local type="$1"   # CMD, SNAP, CORR, DANGER, INFOS, ERROR
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d-%H-%M-%S")
    local username=$(whoami)
    local line="$timestamp : $username : $type : $message"
    
    # Double sortie obligatoire
    echo "$line"
    flock "$LOG_FILE" -c "echo '$line' >> '$LOG_FILE'"
}

# ── Fonction d'aide ──
display_help() {
    echo "Usage: blackbox [OPTIONS] <SERVICE_NAME>"
    echo ""
    echo "Options:"
    echo "  -h         Affiche cette aide"
    echo "  -w         Watch Mode  : surveillance continue"
    echo "  -a         Analyze Mode: analyse forensique"
    echo "  -p         Playback Mode: rejeu de session"
    echo "  -s         Subshell    : isole dans un sous-shell"
    echo "  -f         Fork        : analyse en parallele"
    echo "  -t         Thread      : compression multithreadee"
    echo "  -l <rep>   Log Dir     : repertoire personnalise"
    echo "  -r         Restore     : reset (root uniquement)"
    echo "  -v         Verbose     : mode debogage"
    echo ""
    echo "Exemples:"
    echo "  blackbox -w nginx"
    echo "  blackbox -f -a apache2"
    echo "  blackbox -t -a mysql"
    echo "  blackbox -p 2026-04-21_14-30-00"
}

# ── Gestion des erreurs (codes definis dans le cahier de charge) ──
die() {
    local code="$1"
    local message="$2"
    log_event "ERROR" "$message"
    display_help
    exit "$code"
}

# ── Parse des options avec getopts ──
parse_options() {
    while getopts ":hwapsftvrl:" opt; do
        case $opt in
            h) display_help; exit 0 ;;
            w) MODE="watch" ;;
            a) MODE="analyze" ;;
            p) MODE="playback" ;;
            s) FLAG_SUBSHELL=true ;;
            f) FLAG_FORK=true ;;
            t) FLAG_THREAD=true ;;
            v) FLAG_VERBOSE=true ;;
            l) CUSTOM_LOG_DIR="$OPTARG" ;;
            r) mode_restore ;;
            ?) die 100 "Option inconnue: -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))
    SERVICE_NAME="$1"
}

# ── Initialisation de l'environnement ──
init_environment() {
    [ -n "$CUSTOM_LOG_DIR" ] && LOG_DIR="$CUSTOM_LOG_DIR"
    LOG_FILE="$LOG_DIR/history.log"
    ARCHIVE_DIR="$LOG_DIR/archives"
    mkdir -p "$LOG_DIR" "$ARCHIVE_DIR"
    touch "$LOG_FILE"
    log_event "INFOS" "blackbox demarre — service: $SERVICE_NAME — mode: $MODE"
}

# ── Validation ──
validate() {
    [ -z "$SERVICE_NAME" ] && die 101 "Service name manquant"
    
    if [ "$MODE" = "analyze" ] || [ "$MODE" = "watch" ]; then
        local log_path="/var/log/$SERVICE_NAME"
        [ ! -d "$log_path" ] && die 102 "Dossier de logs introuvable: $log_path"
    fi
    
    if [ "$MODE" = "playback" ]; then
        [ ! -f "$LOG_FILE" ] && die 104 "Fichier history.log non trouve"
    fi
}

# ── Stubs pour Abdelaali et Omar (ils remplissent ces fonctions) ──
mode_watch()    { source ./src/mode_watch.sh;    watch_main "$SERVICE_NAME"; }
mode_analyze()  { source ./src/mode_analyze.sh;  analyze_main "$SERVICE_NAME"; }
mode_playback() { source ./src/mode_playback.sh; playback_main "$SERVICE_NAME"; }
mode_restore()  {
    [ "$(id -u)" != "0" ] && die 103 "Privileges root requis pour -r"
    rm -rf "$LOG_DIR"
    log_event "INFOS" "Environnement reinitialise"
}

# ── Point d'entree principal ──
main() {
    parse_options "$@"
    init_environment
    validate
    
    # Subshell si -s
    if $FLAG_SUBSHELL; then
        ( run_mode ) &   # execute dans un sous-shell en arriere-plan
    else
        run_mode
    fi
}

run_mode() {
    case "$MODE" in
        watch)    mode_watch ;;
        analyze)  mode_analyze ;;
        playback) mode_playback ;;
        *) die 100 "Aucun mode specifie" ;;
    esac
}

main "$@"