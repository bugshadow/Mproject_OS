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

    # Affichage coloré sur le terminal si FLAG_NO_STDOUT n'est pas "true"
    if [ "$FLAG_NO_STDOUT" != "true" ] && [ "$type" != "SNAP" ] && { [ "$type" != "CMD" ] || [ "$FLAG_VERBOSE" = true ]; }; then
        case "$type" in
            "INFOS")  echo -e "${C_GREEN}[✓] ${msg}${C_RESET}" ;;
            "ERROR")  echo -e "${C_RED}[✗] ${msg}${C_RESET}" >&2 ;;
            "WARN")   echo -e "${C_YELLOW}[!] ${msg}${C_RESET}" ;;
            "DANGER") echo -e "\n${C_BRED}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n┃   ALERTE DANGER : ${msg}\n┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${C_RESET}\n" >&2 ;;
            "CMD") 
                [ "$FLAG_VERBOSE" = true ] && echo -e "${C_BLUE}╭──[  Commande ]─────────────────────────────────────────${C_RESET}\n${C_BLUE}│${C_RESET} ${C_CYAN}${msg}${C_RESET}" 
                ;;
            "RET")
                local ret_color="${C_GREEN}Succès"
                [ "$msg" != "0" ] && ret_color="${C_RED}Erreur"
                [ "$FLAG_VERBOSE" = true ] && echo -e "${C_BLUE}│${C_RESET} ↳ Résultat : ${ret_color} (Code ${msg})${C_RESET}"
                ;;
            "CORR")
                [ "$FLAG_VERBOSE" = true ] && echo -e "${C_BRED}╭──[  CORRÉLATION DÉTECTÉE ]─────────────────────────────${C_RESET}\n${C_BRED}│${C_RESET} ${C_YELLOW}${msg}${C_RESET}\n${C_BRED}╰──────────────────────────────────────────────────────────${C_RESET}"
                ;;
            *) echo "$line" ;;
        esac
    fi

    # Écriture atomique dans le fichier
    if [ -n "$LOG_FILE" ] && [ -d "$(dirname "$LOG_FILE")" ]; then
        # On s'assure que le fichier existe avant d'écrire (si le répertoire est accessible)
        if [ ! -f "$LOG_FILE" ]; then
            touch "$LOG_FILE" 2>/dev/null
            chmod 666 "$LOG_FILE" 2>/dev/null
        fi
        
        (
            flock -w 2 200
            echo -e "${line}" >> "$LOG_FILE"
        ) 200>>"$LOG_FILE"
    fi
}
export -f log_event

# Fonction pour afficher la bannière ASCII
print_banner() {
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
}

# Fonction d'aide détaillée (avec ASCII art Dev 1)
display_help() {
    print_banner
    echo -e "$(cat << EOF
${C_CYAN}NOM${C_RESET}
      blackbox - Outil modulaire de surveillance, d'analyse et de rejeu pour serveurs Linux.

${C_CYAN}SYNOPSIS${C_RESET}
      ${C_GREEN}blackbox${C_RESET} [OPTIONS] <SERVICE_NAME>

${C_CYAN}DESCRIPTION${C_RESET}
      blackbox est un utilitaire système complet conçu pour capturer l'historique des commandes,
      surveiller l'état des ressources (CPU, RAM, Disque), et fournir des outils avancés
      d'investigation forensique et d'audit.

${C_CYAN}MODES D'EXÉCUTION PRINCIPAUX${C_RESET} (Un seul mode à la fois)
      ${C_YELLOW}-w${C_RESET}  (Watch)
          Mets en place une surveillance continue. Intercepte le flux des commandes du terminal,
          enregistre des snapshots des performances et alerte face aux exécutions destructrices
          (ex: rm -rf /, chmod 777 /etc). [Module Dev 1 - Actif]
          
      ${C_YELLOW}-a${C_RESET}  (Analyze)
          Analyse forensique. Parcourt, agrège et audite les fichiers logs du service cible.
          Calcule les adresses IP uniques et les fréquences d'erreurs (4xx/5xx). [Module Dev 2]
          
      ${C_YELLOW}-p <DATE>${C_RESET}  (Playback)
          Re-simule ou rejoue l'activité d'une session passée à partir de history.log pour
          réviser précisément ce qui a été tapé au clavier à une date donnée. [Module Dev 3]

${C_CYAN}OPTIONS SUPPLÉMENTAIRES${C_RESET}
      ${C_YELLOW}-s, --subshell${C_RESET}    Déploie au niveau du shell cible un sous-environnement isolé pour -w.
      ${C_YELLOW}-f, --fork${C_RESET}        Active le multithreading multi-processus ('split' + '&') pour -a.
      ${C_YELLOW}-t, --thread${C_RESET}      Optimisation par threads Pthreads en C (.bin/compress_helper) pour -p.
      ${C_YELLOW}-l <REP>${C_RESET}          Spécifie un chemin de log alternatif (Défaut: /var/log/blackbox).
      ${C_YELLOW}-v, --verbose${C_RESET}     Affiche en temps réel le détail des opérations en arrière-plan.
      ${C_YELLOW}-r, --restore${C_RESET}     Détruit et réinitialise tous les journaux du daemon (Mode ROOT exigé).
      ${C_YELLOW}-h, --help${C_RESET}        Affiche ce manuel d'utilisation standard.

${C_CYAN}EXEMPLES STANDARDS${C_RESET}
      1) Surveiller localement (sans accès root) le service 'nginx' :
         ${C_GREEN}./blackbox -l ./var_local/log -s -w nginx${C_RESET}
         
      2) Lancer une analyse à très haute vitesse (pipeline multi-processus) :
         ${C_GREEN}./blackbox -f -a mariadb${C_RESET}
         
      3) Déboguer l'audit d'hier et compresser rapidement grâce au Threading C :
         ${C_GREEN}./blackbox -v -t -p "2026-04-24" sshd${C_RESET}

${C_CYAN}RETOURS ET CODE D'ERREURS${C_RESET}
      0   Généralement: Succès
      100 Option inconnue ou absence de Mode (w/a/p)
      101 Nom du service obligatoire manquant
      102 Répertoire source non trouvé sur la machine (logs introuvables)
      103 Tentative d'écrasement des logs sans les droits superutilisateur (root)
      104 Fichier 'history.log' indisponible pendant un mode lecture (Playback)
EOF
)"
}

# Fonction d'aide condensée après erreur (similaire à -h)
display_error_help() {
    echo -e "\n${C_YELLOW}--- DOCUMENTATION RAPIDE ---${C_RESET}"
    echo -e "${C_CYAN}SYNOPSIS${C_RESET} :"
    echo -e "      ${C_GREEN}blackbox${C_RESET} [OPTIONS] <SERVICE_NAME>"
    echo -e "\n${C_CYAN}MODES D'EXÉCUTION PRINCIPAUX${C_RESET} (Un seul mode à la fois) :"
    echo -e "      ${C_YELLOW}-w${C_RESET}  (Watch)   : Surveillance continue (intercepte les commandes terminal)."
    echo -e "      ${C_YELLOW}-a${C_RESET}  (Analyze) : Analyse forensique (agrège et audite les fichiers logs)."
    echo -e "      ${C_YELLOW}-p${C_RESET}  (Playback): Re-simule l'activité d'une session passée."
    echo -e "\n${C_CYAN}OPTIONS OBLIGATOIRES${C_RESET} :"
    echo -e "      ${C_YELLOW}-s, --subshell${C_RESET} : Exécute le programme dans un sous-shell cible."
    echo -e "      ${C_YELLOW}-f, --fork${C_RESET}     : Active le multiprocessing (découpage) en arrière-plan."
    echo -e "      ${C_YELLOW}-t, --thread${C_RESET}   : Optimisation par threads Pthreads en C."
    echo -e "      ${C_YELLOW}-l <REP>${C_RESET}       : Spécifie un répertoire de stockage des logs."
    echo -e "      ${C_YELLOW}-r, --restore${C_RESET}  : Réinitialise les paramètres par défaut (Admin)."
    echo -e "\n${C_CYAN}Pour lire le manuel complet avec des exemples, tapez :${C_RESET} ./blackbox -h"
    echo -e "${C_YELLOW}----------------------------${C_RESET}\n"
}

# Gestion fatale des erreurs (Code 100 à 104)
die() {
    local code="$1"
    local message="$2"
    log_event "ERROR" "$message"
    echo ""
    display_help
    exit "$code"
}