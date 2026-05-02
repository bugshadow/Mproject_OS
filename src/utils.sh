#!/bin/bash

# ==============================================================================
# Fonctions Utilitaires & Core — Partagees entre tous les Devs
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

    # Affichage colore sur le terminal si FLAG_NO_STDOUT n'est pas "true"
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
                local ret_color="${C_GREEN}Succes"
                [ "$msg" != "0" ] && ret_color="${C_RED}Erreur"
                [ "$FLAG_VERBOSE" = true ] && echo -e "${C_BLUE}│${C_RESET} ↳ Resultat : ${ret_color} (Code ${msg})${C_RESET}"
                ;;
            "CORR")
                [ "$FLAG_VERBOSE" = true ] && echo -e "${C_BRED}╭──[  CORReLATION DeTECTeE ]─────────────────────────────${C_RESET}\n${C_BRED}│${C_RESET} ${C_YELLOW}${msg}${C_RESET}\n${C_BRED}╰──────────────────────────────────────────────────────────${C_RESET}"
                ;;
            *) echo "$line" ;;
        esac
    fi

    # ecriture atomique dans le fichier
    if [ -n "$LOG_FILE" ] && [ -d "$(dirname "$LOG_FILE")" ]; then
        # On s'assure que le fichier existe avant d'ecrire (si le repertoire est accessible)
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

# Fonction pour afficher la banniere ASCII
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

# Fonction d'aide detaillee (avec ASCII art Dev 1)
display_help() {
    print_banner
    echo -e "$(cat << EOF
${C_CYAN}NOM${C_RESET}
      blackbox - Outil modulaire de surveillance, d'analyse et de rejeu pour serveurs Linux.

${C_CYAN}SYNOPSIS${C_RESET}
      ${C_GREEN}blackbox${C_RESET} [OPTIONS] <SERVICE_NAME>

${C_CYAN}DESCRIPTION${C_RESET}
      blackbox est un utilitaire systeme complet conçu pour capturer l'historique des commandes,
      surveiller l'etat des ressources (CPU, RAM, Disque), et fournir des outils avances
      d'investigation forensique et d'audit.

${C_CYAN}MODES D'EXeCUTION PRINCIPAUX${C_RESET} (Un seul mode a la fois)
      ${C_YELLOW}-w${C_RESET}  (Watch)
          Mets en place une surveillance continue. Intercepte le flux des commandes du terminal,
          enregistre des snapshots des performances et alerte face aux executions destructrices
          (ex: rm -rf /, chmod 777 /etc) avec envoi de notifications instantanees Telegram.
          [Module Dev 1 - Actif]
          
      ${C_YELLOW}-a${C_RESET}  (Analyze)
          Analyse forensique. Parcourt, agrege et audite les fichiers logs du service cible.
          Calcule les adresses IP uniques et les frequences d'erreurs (4xx/5xx). [Module Dev 2]
          
      ${C_YELLOW}-p <DATE>${C_RESET}  (Playback)
          Re-simule ou rejoue l'activite d'une session passee a partir de history.log pour
          reviser precisement ce qui a ete tape au clavier a une date donnee. [Module Dev 3]

${C_CYAN}OPTIONS SUPPLeMENTAIRES${C_RESET}
      ${C_YELLOW}-s, --subshell${C_RESET}    Deploie au niveau du shell cible un sous-environnement isole pour -w.
      ${C_YELLOW}-f, --fork${C_RESET}        Active le multithreading multi-processus ('split' + '&') pour -a.
      ${C_YELLOW}-t, --thread${C_RESET}      Optimisation par threads Pthreads en C (.bin/compress_helper) pour -p.
      ${C_YELLOW}-l <REP>${C_RESET}          Specifie un chemin de log alternatif (Defaut: /var/log/blackbox).
      ${C_YELLOW}-v, --verbose${C_RESET}     Affiche en temps reel le detail des operations en arriere-plan.
      ${C_YELLOW}-A, --alert${C_RESET}       Active les alertes Telegram (Mode Watch).
      ${C_YELLOW}-r, --restore${C_RESET}     Detruit et reinitialise tous les journaux du daemon (Mode ROOT exige).
      ${C_YELLOW}-h, --help${C_RESET}        Affiche ce manuel d'utilisation standard.

${C_CYAN}EXEMPLES STANDARDS${C_RESET}
      1) Surveiller localement (sans acces root) le service 'nginx' :
         ${C_GREEN}./blackbox -l ./var_local/log -s -w nginx${C_RESET}
         
      2) Lancer une analyse a tres haute vitesse (pipeline multi-processus) :
         ${C_GREEN}./blackbox -f -a mariadb${C_RESET}
         
      3) Deboguer l'audit d'hier et compresser rapidement grâce au Threading C :
         ${C_GREEN}./blackbox -v -t -p "2026-04-24" sshd${C_RESET}

${C_CYAN}RETOURS ET CODE D'ERREURS${C_RESET}
      0   Generalement: Succes
      100 Option inconnue ou absence de Mode (w/a/p)
      101 Nom du service obligatoire manquant
      102 Repertoire source non trouve sur la machine (logs introuvables)
      103 Tentative d'ecrasement des logs sans les droits superutilisateur (root)
      104 Fichier 'history.log' indisponible pendant un mode lecture (Playback)
EOF
)"
}

# Fonction d'aide condensee apres erreur (similaire a -h)
display_error_help() {
    echo -e "\n${C_YELLOW}--- DOCUMENTATION RAPIDE ---${C_RESET}"
    echo -e "${C_CYAN}SYNOPSIS${C_RESET} :"
    echo -e "      ${C_GREEN}blackbox${C_RESET} [OPTIONS] <SERVICE_NAME>"
    echo -e "\n${C_CYAN}MODES D'EXeCUTION PRINCIPAUX${C_RESET} (Un seul mode a la fois) :"
    echo -e "      ${C_YELLOW}-w${C_RESET}  (Watch)   : Surveillance continue (intercepte les commandes terminal)."
    echo -e "      ${C_YELLOW}-a${C_RESET}  (Analyze) : Analyse forensique (agrege et audite les fichiers logs)."
    echo -e "      ${C_YELLOW}-p${C_RESET}  (Playback): Re-simule l'activite d'une session passee."
    echo -e "\n${C_CYAN}OPTIONS OBLIGATOIRES${C_RESET} :"
    echo -e "      ${C_YELLOW}-s, --subshell${C_RESET} : Execute le programme dans un sous-shell cible."
    echo -e "      ${C_YELLOW}-f, --fork${C_RESET}     : Active le multiprocessing (decoupage) en arriere-plan."
    echo -e "      ${C_YELLOW}-t, --thread${C_RESET}   : Optimisation par threads Pthreads en C."
    echo -e "      ${C_YELLOW}-l <REP>${C_RESET}       : Specifie un repertoire de stockage des logs."
    echo -e "      ${C_YELLOW}-A, --alert${C_RESET}       : Active les alertes Telegram (Mode Watch)."
    echo -e "      ${C_YELLOW}-r, --restore${C_RESET}  : Reinitialise les parametres par defaut (Admin)."
    echo -e "\n${C_CYAN}Pour lire le manuel complet avec des exemples, tapez :${C_RESET} ./blackbox -h"
    echo -e "${C_YELLOW}----------------------------${C_RESET}\n"
}
