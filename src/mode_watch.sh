#!/bin/bash

# ==============================================================================
# MODE WATCH : Surveillance Temps Réel (Rôle de Dev 1)
# ==============================================================================

# Fonction d'interception appelée avant chaque affichage de prompt
blackbox_log_cmd() {
    local exit_code=$?
    local cmd
    cmd=$(history 1 | sed -e "s/^[ ]*[0-9]*[ ]*//")
    
    if [ -n "$cmd" ]; then
        log_event "CMD" "${PWD} : ${cmd}"
        log_event "RET" "${exit_code}"
        
        # Détection des commandes dangereuses (Regex Bash dans une variable pour éviter les erreurs de syntaxe)
        local danger_pattern='rm -rf /|chmod 777 /etc|dd if=/dev/zero|mkfs|:\(\)\{.*\}|> /dev/sda'
        if [[ "$cmd" =~ $danger_pattern ]]; then
            log_event "DANGER" "Commande critique détectée : $cmd"
            echo -e "${C_BRED}[⚠] ALERTE ROUGE : Exécution d'une commande destructrice détectée !${C_RESET}"
        fi

        # Snapshot Système
        local cpu ram disk
        cpu=$(ps aux --sort=-%cpu 2>/dev/null | head -2 | tail -1 | awk '{print $3}')
        ram=$(free -h 2>/dev/null | awk '/Mem/ {print $7}')
        disk=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')
        
        log_event "SNAP" "CPU=${cpu:-N/A}% | RAM_Avail=${ram:-N/A} | Disk_Root=${disk:-N/A}"
        
        if [ "$FLAG_VERBOSE" = true ]; then
            echo -e "┌───────────────────┬──────────────┬────────────┐"
            echo -e "│ Métrique          │ Valeur       │ Statut     │"
            echo -e "├───────────────────┼──────────────┼────────────┤"
            echo -e "│ CPU Usage         │ ${cpu:-N/A}%         │ -          │"
            echo -e "│ RAM Available     │ ${ram:-N/A}       │ -          │"
            echo -e "│ Disk /            │ ${disk:-N/A}        │ -          │"
            echo -e "└───────────────────┴──────────────┴────────────┘"
        fi
    fi
}
# L'export est crucial pour que le PROMPT_COMMAND puisse l'appeler dans les processus enfants
export -f blackbox_log_cmd

# Point d'entrée interne pour le Watch Mode
watch_main() {
    local service="$1"
    
    log_event "INFOS" "Surveillance active sur les commandes utilisateur pour le service $service"
    export PROMPT_COMMAND="blackbox_log_cmd; $PROMPT_COMMAND"
    
    if [ "$FLAG_SUBSHELL" = false ]; then
        # On remplace le processus actuel par un terminal Bash interactif (mais surveillé)
        exec bash
    fi
}
