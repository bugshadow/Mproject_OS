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
    
    # Adaptation pour l'environnement de test local (si LOG_DIR est relatif)
    if [[ "$LOG_DIR" == ./* ]]; then
        svc_log="./tests/sample_logs/${SERVICE_NAME}/error.log"
    fi

    [ ! -f "$svc_log" ] && return
    
    local current_size
    current_size=$(stat -c%s "$svc_log" 2>/dev/null || echo 0)
    local pre_size=${__BLACKBOX_PRE_SIZE:-0}

    # S'il y a de nouveaux octets écrits dans le log
    if [ "$current_size" -gt "$pre_size" ]; then
        local diff_size=$((current_size - pre_size))
        local recent_errors
        # On lit seulement les nouveaux octets ajoutés après la commande
        recent_errors=$(tail -c "$diff_size" "$svc_log" 2>/dev/null | grep -iE "error|critical|fail|fatal" | tail -5 | tr '\n' ' ')
        if [ -n "$recent_errors" ]; then
            log_event "CORR" "Commande '$cmd' corrélée avec erreur(s) récente(s) : ${recent_errors:0:200}"
        fi
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
    local svc_log="/var/log/${SERVICE_NAME}/error.log"
    
    # Adaptation pour l'environnement de test local (si LOG_DIR est relatif)
    if [[ "$LOG_DIR" == ./* ]]; then
        svc_log="./tests/sample_logs/${SERVICE_NAME}/error.log"
    fi

    if [ -f "$svc_log" ]; then
        __BLACKBOX_PRE_SIZE=$(stat -c%s "$svc_log" 2>/dev/null || echo 0)
    else
        __BLACKBOX_PRE_SIZE=0
    fi
}

# ------------------------------------------------------------
# Hook exécuté juste APRÈS chaque commande (PROMPT_COMMAND)
# ------------------------------------------------------------
__blackbox_watch_postcmd() {
    local last_exit=$?
    local last_cmd cmdline timestamp hist_line hist_id
    
    # Récupérer la ligne d'historique complète
    hist_line=$(history 1 2>/dev/null)
    # Extraire l'ID (premier mot)
    hist_id=$(echo "$hist_line" | awk '{print $1}')
    # Extraire la commande
    last_cmd=$(echo "$hist_line" | sed 's/^[ ]*[0-9]\+[ ]*//')
    
    [ -z "$last_cmd" ] && return
    
    # Ignorer la toute première exécution (qui capture la dernière commande de la session précédente)
    if [ "$__BLACKBOX_FIRST_RUN" = "true" ]; then
        export __BLACKBOX_FIRST_RUN="false"
        export __BLACKBOX_LAST_HIST_ID="$hist_id"
        return
    fi

    # Anti-doublons : on ignore si l'ID d'historique est le même (ex: juste 'Entrée')
    if [ "$hist_id" = "$__BLACKBOX_LAST_HIST_ID" ]; then
        return
    fi
    export __BLACKBOX_LAST_HIST_ID="$hist_id"
    
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
    local install_dir="$(pwd)"
    
    cat > "$hook_file" << 'HOOK_EOF'
# Blackbox Watch Hook – installé automatiquement
export SERVICE_NAME="__SERVICE__"
export LOG_FILE="__LOG_FILE__"
export FLAG_VERBOSE="__VERBOSE__"
export FLAG_NO_STDOUT="true"

# Rechargement des fonctions
source __INSTALL_DIR__/src/utils.sh 2>/dev/null
source __INSTALL_DIR__/src/mode_watch.sh 2>/dev/null

# Message de bienvenue pour tous les utilisateurs (Audit Visuel)
if [ -z "$__BLACKBOX_BANNER_SHOWN" ]; then
    echo -e "\e[1;31m[!] SURVEILLANCE ACTIVÉE : Ce shell est enregistré par Blackbox.\e[0m"
    export __BLACKBOX_BANNER_SHOWN="true"
fi

__install_local_hook
HOOK_EOF
    sed -i "s|__SERVICE__|$SERVICE_NAME|g" "$hook_file"
    sed -i "s|__LOG_FILE__|$LOG_FILE|g" "$hook_file"
    sed -i "s|__VERBOSE__|$FLAG_VERBOSE|g" "$hook_file"
    sed -i "s|__INSTALL_DIR__|$install_dir|g" "$hook_file"
    # On s'assure que le répertoire d'installation est accessible en lecture pour tous
    chmod -R 755 "$install_dir" 2>/dev/null
    
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
        
        # Vérification critique : si le projet est dans /home/user, s'assurer que /home/user est traversable
        local home_parent=$(dirname "$(pwd)")
        if [ "$home_parent" = "/home" ] || [[ "$(pwd)" == /home/* ]]; then
            local user_home=$(echo "$(pwd)" | cut -d/ -f1-3)
            if [ -n "$user_home" ] && [ ! -x "$user_home" ]; then
                log_event "WARN" "Votre dossier personnel ($user_home) restreint l'accès aux autres utilisateurs."
                log_event "INFOS" "Fix automatique des permissions du dossier personnel..."
                chmod 755 "$user_home" 2>/dev/null
            fi
        fi

        # Alerte Spéciale WSL / Partition Windows
        if [[ "$(pwd)" == /mnt/* ]]; then
            log_event "WARN" "ATTENTION : Vous êtes sur une partition Windows (/mnt/)."
            log_event "WARN" "La capture multi-utilisateurs risque d'échouer à cause des permissions WSL."
            log_event "INFOS" "Conseil : Déplacez le projet dans /home/ pour un test 100% fonctionnel."
        fi
    else
        log_event "WARN" "Pas de privilèges root – hook limité à la session courante"
    fi
    
    # Activation locale pour le shell courant (on évite la pollution du rcfile)
    # On définit d'abord les variables et fonctions, puis on lance bash avec le hook activé via PROMPT_COMMAND
    export -f __blackbox_snapshot __blackbox_correlate \
    __blackbox_danger_check __blackbox_danger_patterns \
    __blackbox_watch_precmd __blackbox_watch_postcmd log_event
    
    export __BLACKBOX_FIRST_RUN="true"
    
    # On prépare un script temporaire minimal qui sera sourcé par le nouveau shell
    local temp_rc
    temp_rc=$(mktemp /tmp/blackbox_rc.XXXXXX)
    cat > "$temp_rc" <<'EOF'
# Charger le bashrc habituel s'il existe
[ -f ~/.bashrc ] && source ~/.bashrc 2>/dev/null

# Amélioration du design (Prompt et Bannière)
export PS1="\[\e[1;31m\][⚫ BLACKBOX WATCH]\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\] \$ "

# Définir le piège DEBUG et PROMPT_COMMAND (sans rien afficher)
trap '__blackbox_watch_precmd' DEBUG
PROMPT_COMMAND="__blackbox_watch_postcmd;${PROMPT_COMMAND:+$PROMPT_COMMAND}"

# Bannière d'accueil temps réel
echo -e "\e[1;31m"
echo "  ___.   .__                 __  ___.                 "
echo "  \_ |__ |  | _____    ____ |  | \_ |__   _______  ___"
echo "   | __ \|  | \__  \ _/ ___\|  |/ / __ \ /  _ \  \/  /"
echo "   | \_\ \  |__/ __ \\  \___|    <| \_\ (  <_> >    < "
echo "   |___  /____(____  /\___  >__|_ \___  /\____/__/\_ \\"
echo "       \/          \/     \/     \/   \/            \/"
echo -e "\e[0m"
echo -e "\e[1;33m[*] Mode Surveillance (Watch) Activé. PID: $$\e[0m"
echo -e "\e[1;36m[*] Enregistrement en temps réel des commandes vers $LOG_FILE\e[0m"
echo -e "\e[1;90m[*] Tapez 'exit' pour quitter le mode watch.\e[0m"
echo ""
EOF
    
    log_event "INFOS" "Session surveillée prête. Lancement d'un shell interactif..."
    exec bash --rcfile "$temp_rc"
}