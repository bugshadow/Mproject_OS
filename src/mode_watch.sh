#!/bin/bash
# ==============================================================================
# mode_watch.sh — Module Watch (Dev 1)
# Boîte noire légère pour serveurs Linux — blackbox
# ==============================================================================
# Ce module est sourcé par le script principal blackbox.
# Il définit la fonction watch_main(), appelée lors de l'option -w.
# ==============================================================================

# ------------------------------------------------------------
# Fonction utilitaire : capture d'un snapshot système
# ------------------------------------------------------------
__blackbox_snapshot() {
    local loadavg cpu_mem disk topproc
    loadavg=$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}' | tr -d ' ')
    cpu_mem=$(free -m 2>/dev/null | awk '/^Mem:/{printf "%s/%s", $3, $2}')
    disk=$(df -h / 2>/dev/null | awk 'NR==2{print $5}')
    topproc=$(ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1{print $11}' | head -5 | tr '\n' ',' | sed 's/,$//')
    echo "CPU=${loadavg:-N/A} MEM=${cpu_mem:-N/A} DISK=${disk:-N/A} TOP5=${topproc:-none}"
}

# ------------------------------------------------------------
# Fonction de corrélation basique avec le log du service
# ------------------------------------------------------------
__blackbox_correlate() {
    local cmd="$1" ts="$2"
    local svc_log="/var/log/${SERVICE_NAME}/error.log"
    [ ! -f "$svc_log" ] && return
    
    # On cherche des erreurs apparues dans les 2 dernières minutes (approximation)
    local recent_errors
    recent_errors=$(tail -200 "$svc_log" 2>/dev/null | grep -iE "error|critical|fail|fatal" | tail -5 | tr '\n' ' ')
    if [ -n "$recent_errors" ]; then
        log_event "CORR" "Commande '$cmd' corrélée avec erreur(s) récente(s) : ${recent_errors:0:200}"
    fi
}

# ------------------------------------------------------------
# Liste des patterns dangereux
# ------------------------------------------------------------
__blackbox_danger_patterns() {
    cat <<'EOF'
rm\s+-rf\s+/
chmod\s+777\s+/(etc|bin|sbin|lib)
dd\s+if=.*\s+of=/dev/sd
mkfs\.
:(){ :|:& };:
> /dev/sda
EOF
}

__blackbox_danger_check() {
    local cmd="$1"
    while read -r pattern; do
        [ -z "$pattern" ] && continue
        if echo "$cmd" | grep -Eq "$pattern"; then
            log_event "DANGER" "Commande dangereuse : $cmd"
            return
        fi
    done < <(__blackbox_danger_patterns)
}

# ------------------------------------------------------------
# Hook exécuté juste AVANT chaque commande (trap DEBUG)
# ------------------------------------------------------------
__blackbox_watch_precmd() {
    # On mémorise la date et la taille du log du service avant la commande
    __BLACKBOX_PRE_TS=$(date '+%Y-%m-%d-%H-%M-%S')
    if [ -f "/var/log/${SERVICE_NAME}/error.log" ]; then
        __BLACKBOX_PRE_SIZE=$(stat -c%s "/var/log/${SERVICE_NAME}/error.log" 2>/dev/null || echo 0)
    else
        __BLACKBOX_PRE_SIZE=0
    fi
}

# ------------------------------------------------------------
# Hook exécuté juste APRÈS chaque commande (PROMPT_COMMAND)
# ------------------------------------------------------------
__blackbox_watch_postcmd() {
    local last_exit=$?
    local last_cmd cmdline timestamp
    
    # Récupérer la dernière commande tapée (sans le numéro d'historique)
    last_cmd=$(history 1 2>/dev/null | sed 's/^[ ]*[0-9]\+[ ]*//')
    [ -z "$last_cmd" ] && return
    
    # Éviter de capturer le hook lui-même ou des commandes internes
    [[ "$last_cmd" == "__blackbox_watch_"* ]] && return
    [[ "$last_cmd" == "history 1" ]] && return
    
    timestamp="$__BLACKBOX_PRE_TS"  # on utilise le timestamp d'avant la commande
    [ -z "$timestamp" ] && timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
    
    # 1. Journaliser la commande (CMD)
    log_event "CMD" "${PWD}: $last_cmd"
    # 2. Journaliser le code de retour (RET)
    log_event "RET" "$last_exit"
    
    # 3. Snapshot système (SNAP)
    local snap
    snap=$(__blackbox_snapshot)
    log_event "SNAP" "$snap"
    
    # 4. Détection de commandes dangereuses
    __blackbox_danger_check "$last_cmd"
    
    # 5. Corrélation avec les logs du service
    __blackbox_correlate "$last_cmd" "$timestamp"
}

# ------------------------------------------------------------
# Installation du hook dans le shell courant
# ------------------------------------------------------------
__install_local_hook() {
    # Ces fonctions sont rendues disponibles dans le shell courant
    export -f __blackbox_snapshot __blackbox_correlate \
    __blackbox_danger_check __blackbox_watch_precmd __blackbox_watch_postcmd log_event
    
    # On pose le trap DEBUG (avant chaque commande) et PROMPT_COMMAND (après)
    trap '__blackbox_watch_precmd' DEBUG
    PROMPT_COMMAND="__blackbox_watch_postcmd;${PROMPT_COMMAND:+$PROMPT_COMMAND}"
    log_event "INFOS" "Hook Watch activé pour la session courante (shell PID $$)"
}

# ------------------------------------------------------------
# Installation système (root) – pour surveillance multi-utilisateurs
# ------------------------------------------------------------
__install_system_hook() {
    local hook_file="/etc/profile.d/blackbox-watch.sh"
    cat > "$hook_file" << 'HOOK_EOF'
# Blackbox Watch Hook – installé automatiquement
export SERVICE_NAME="__SERVICE__"
export LOG_FILE="__LOG_FILE__"
export FLAG_VERBOSE="__VERBOSE__"
# On recharge les fonctions de blackbox depuis le répertoire d'installation
source /opt/blackbox/src/mode_watch.sh 2>/dev/null || {
    # Fallback : on définit les fonctions minimales directement
    # (À compléter si le chemin n'est pas standard – ici on suppose que le sourcing a déjà eu lieu)
    return
}
__install_local_hook
HOOK_EOF
    sed -i "s|__SERVICE__|$SERVICE_NAME|g" "$hook_file"
    sed -i "s|__LOG_FILE__|$LOG_FILE|g" "$hook_file"
    sed -i "s|__VERBOSE__|$FLAG_VERBOSE|g" "$hook_file"
    chmod 644 "$hook_file"
    log_event "INFOS" "Hook système installé dans $hook_file"
}

# ------------------------------------------------------------
# Fonction principale du mode Watch
# ------------------------------------------------------------
watch_main() {
    local service="$1"
    log_event "INFOS" "Lancement du mode Watch pour le service '$service'"
    
    # Vérification : pour une surveillance globale, il faut être root
    if [ "$(id -u)" -eq 0 ]; then
        log_event "INFOS" "Installation du hook système (global)"
        __install_system_hook
    else
        log_event "WARN" "Pas de privilèges root – hook limité à la session courante"
    fi
    
    # Activation locale pour le shell courant (on évite la pollution du rcfile)
    # On définit d'abord les variables et fonctions, puis on lance bash avec le hook activé via PROMPT_COMMAND
    export -f __blackbox_snapshot __blackbox_correlate \
    __blackbox_danger_check __blackbox_danger_patterns \
    __blackbox_watch_precmd __blackbox_watch_postcmd log_event
    
    # On prépare un script temporaire minimal qui sera sourcé par le nouveau shell
    local temp_rc
    temp_rc=$(mktemp /tmp/blackbox_rc.XXXXXX)
    cat > "$temp_rc" <<'EOF'
# Charger le bashrc habituel s'il existe
[ -f ~/.bashrc ] && source ~/.bashrc 2>/dev/null

# Définir le piège DEBUG et PROMPT_COMMAND (sans rien afficher)
trap '__blackbox_watch_precmd' DEBUG
PROMPT_COMMAND="__blackbox_watch_postcmd;${PROMPT_COMMAND:+$PROMPT_COMMAND}"

# Message discret pour confirmer l'activation (sur stderr, pas dans le rcfile)
echo "[blackbox] Shell surveillé actif (PID $$)" >&2
EOF
    
    log_event "INFOS" "Session surveillée prête. Lancement d'un shell interactif..."
    exec bash --rcfile "$temp_rc"
}