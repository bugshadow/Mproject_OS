#!/bin/bash

# ==============================================================================
# BLACKBOX — MODE ANALYZE : Analyse Forensique & Correlation
# ENSET Mohammedia — Module SE 2025/2026
# Rôle : Dev 2 — Analysis & Forensics
# ==============================================================================

# ── Constantes ──
readonly DANGER_THRESHOLD=5      # secondes max entre commande et erreur pour correler
readonly MAX_LINES_DISPLAY=10    # nb de lignes max a afficher dans le terminal
readonly LOG_SIZE_FORK=104857600 # 100MB en bytes → seuil pour activer le fork

# ==============================================================================
# FONCTION PRINCIPALE — appelee par blackbox main
# ==============================================================================
analyze_main() {
    local service="$1"

    echo -e "\n${C_CYAN}╔══════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_CYAN}║       BLACKBOX — Analyse Forensique : ${service}        ${C_RESET}"
    echo -e "${C_CYAN}╚══════════════════════════════════════════════════════╝${C_RESET}\n"

    log_event "INFOS" "Demarrage de l'analyse forensique pour le service: $service"

    # ── Determiner le chemin des logs du service ──
    local log_path
    log_path=$(_resolve_log_path "$service")

    if [ -z "$log_path" ]; then
        log_event "ERROR" "Impossible de trouver les logs pour: $service"
        die 102 "Dossier de logs introuvable pour $service"
    fi

    log_event "INFOS" "Chemin des logs resolu: $log_path"

    # ── Phase 1 : Profilage Systeme ──
    _phase_system_profiling

    # ── Phase 2 : Analyse des Logs (avec ou sans Fork) ──
    if [ "$FLAG_FORK" = true ]; then
        _phase_log_forensics_fork "$service" "$log_path"
    else
        _phase_log_forensics "$service" "$log_path"
    fi

    # ── Phase 3 : Correlation Commandes ↔ Erreurs ──
    _phase_correlation "$service" "$log_path"

    # ── Phase 4 : Generation du Rapport Compresse ──
    _phase_generate_report "$service"

    echo -e "\n${C_GREEN}╔══════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_GREEN}║         Analyse terminee avec succes ✓               ${C_RESET}"
    echo -e "${C_GREEN}╚══════════════════════════════════════════════════════╝${C_RESET}\n"
    log_event "INFOS" "Analyse forensique terminee pour: $service"
}

# ==============================================================================
# ReSOLUTION DU CHEMIN DES LOGS
# ==============================================================================
_resolve_log_path() {
    local service="$1"
    local candidates=(
        "/var/log/$service"
        "./tests/sample_logs"
        "./var/log/$service"
    )
    for path in "${candidates[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    # Chercher un fichier log direct
    if [ -f "/var/log/${service}.log" ]; then
        echo "/var/log"
        return 0
    fi
    echo ""
    return 1
}

# ==============================================================================
# PHASE 1 — PROFILAGE SYSTeME
# Capture l'etat du systeme au moment de l'analyse
# ==============================================================================
_phase_system_profiling() {
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_YELLOW}  PHASE 1 — Profilage Systeme${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"

    local ts
    ts=$(date "+%Y-%m-%d-%H-%M-%S")

    # ── CPU ──
    local cpu_idle cpu_usage load_avg
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%')
    cpu_usage=$(echo "scale=1; 100 - ${cpu_idle:-0}" | bc 2>/dev/null || echo "N/A")
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)

    # ── RAM ──
    local ram_total ram_used ram_free ram_percent
    ram_total=$(free -m | awk '/^Mem:/{print $2}')
    ram_used=$(free -m  | awk '/^Mem:/{print $3}')
    ram_free=$(free -m  | awk '/^Mem:/{print $4}')
    ram_percent=$(echo "scale=1; ${ram_used:-0} * 100 / ${ram_total:-1}" | bc 2>/dev/null || echo "N/A")

    # ── Disque ──
    local disk_info
    disk_info=$(df -h / | awk 'NR==2{printf "%s utilise sur %s (%s)", $3, $2, $5}')

    # ── Top 5 Processus CPU ──
    local top_procs
    top_procs=$(ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6{printf "    %-20s CPU: %s%%\n", $11, $3}')

    echo -e "  ${C_GREEN}CPU Usage   :${C_RESET} ${cpu_usage}%"
    echo -e "  ${C_GREEN}Load Average:${C_RESET} ${load_avg}"
    echo -e "  ${C_GREEN}RAM         :${C_RESET} ${ram_used}MB / ${ram_total}MB (${ram_percent}% utilise)"
    echo -e "  ${C_GREEN}RAM Libre   :${C_RESET} ${ram_free}MB"
    echo -e "  ${C_GREEN}Disque (/)  :${C_RESET} ${disk_info}"
    echo -e "  ${C_GREEN}Top Processus par CPU :${C_RESET}"
    echo -e "${top_procs}"

    local snap_msg="CPU:${cpu_usage}% | RAM:${ram_used}/${ram_total}MB(${ram_percent}%) | Disk:${disk_info} | Load:${load_avg}"
    log_event "SNAP" "$snap_msg"
}

# ==============================================================================
# PHASE 2A — ANALYSE DES LOGS (MODE NORMAL)
# ==============================================================================
_phase_log_forensics() {
    local service="$1"
    local log_path="$2"

    echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_YELLOW}  PHASE 2 — Analyse Forensique des Logs${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"

    # Trouver tous les fichiers log dans le dossier
    local log_files
    mapfile -t log_files < <(find "$log_path" -maxdepth 2 -type f -name "*.log" 2>/dev/null)

    if [ ${#log_files[@]} -eq 0 ]; then
        log_event "WARN" "Aucun fichier .log trouve dans $log_path"
        echo -e "  ${C_YELLOW}[!] Aucun fichier .log trouve dans $log_path${C_RESET}"
        return
    fi

    # Stocker les resultats pour le rapport
    export ANALYSIS_RESULTS_FILE="/tmp/blackbox_analysis_$$.txt"
    : > "$ANALYSIS_RESULTS_FILE"

    for log_file in "${log_files[@]}"; do
        _analyze_single_file "$service" "$log_file"
    done

    log_event "INFOS" "Analyse des logs terminee — ${#log_files[@]} fichier(s) traite(s)"
}

# ==============================================================================
# PHASE 2B — ANALYSE DES LOGS (MODE FORK)
# Decoupe les gros fichiers en 4 morceaux et analyse en parallele
# ==============================================================================
_phase_log_forensics_fork() {
    local service="$1"
    local log_path="$2"

    echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_YELLOW}  PHASE 2 — Analyse Forensique (Mode FORK Parallele)${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"

    log_event "INFOS" "Mode Fork active — analyse parallele des logs"

    local log_files
    mapfile -t log_files < <(find "$log_path" -maxdepth 2 -type f -name "*.log" 2>/dev/null)

    export ANALYSIS_RESULTS_FILE="/tmp/blackbox_analysis_$$.txt"
    : > "$ANALYSIS_RESULTS_FILE"

    local PIDS=()

    for log_file in "${log_files[@]}"; do
        local file_size
        file_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)

        if [ "$file_size" -gt "$LOG_SIZE_FORK" ]; then
            echo -e "  ${C_CYAN}[FORK] Fichier volumineux detecte: $(basename "$log_file") ($(( file_size / 1024 / 1024 ))MB)${C_RESET}"
            echo -e "  ${C_CYAN}[FORK] Decoupage en 4 morceaux → analyse parallele...${C_RESET}"

            local tmp_dir="/tmp/blackbox_fork_$$"
            mkdir -p "$tmp_dir"

            # Decouper le fichier en 4 parties
            split -n 4 "$log_file" "$tmp_dir/chunk_" 2>/dev/null

            local chunk_results=()
            for chunk in "$tmp_dir"/chunk_*; do
                local chunk_result="/tmp/blackbox_chunk_result_${BASHPID}_$(basename "$chunk").txt"
                chunk_results+=("$chunk_result")
                (
                    _analyze_chunk "$chunk" "$chunk_result"
                ) &
                PIDS+=($!)
                echo -e "  ${C_CYAN}[FORK] PID $! → analyse de $(basename "$chunk")${C_RESET}"
            done

            # Attendre tous les processus fils
            for pid in "${PIDS[@]}"; do
                wait "$pid"
                echo -e "  ${C_GREEN}[FORK] PID $pid termine ✓${C_RESET}"
            done

            # Fusionner les resultats
            _merge_fork_results "${chunk_results[@]}"

            rm -rf "$tmp_dir"
            log_event "INFOS" "Fork termine — 4 processus paralleles ont analyse $(basename "$log_file")"

        else
            # Fichier petit → analyse normale
            (
                _analyze_single_file "$service" "$log_file"
            ) &
            PIDS+=($!)
        fi
    done

    # Attendre tous les processus restants
    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null
    done

    log_event "INFOS" "Analyse Fork terminee — ${#log_files[@]} fichier(s) traite(s)"
}

# ==============================================================================
# ANALYSE D'UN SEUL FICHIER LOG
# ==============================================================================
_analyze_single_file() {
    local service="$1"
    local log_file="$2"
    local filename
    filename=$(basename "$log_file")

    echo -e "\n  ${C_BLUE}▶ Fichier: $filename${C_RESET}"

    # ── IPs Uniques + Frequences ──
    echo -e "  ${C_GREEN}Top IPs connectees:${C_RESET}"
    local top_ips
    top_ips=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$log_file" 2>/dev/null \
        | sort | uniq -c | sort -rn | head -"$MAX_LINES_DISPLAY")

    if [ -n "$top_ips" ]; then
        echo "$top_ips" | while read -r count ip; do
            echo -e "    ${count}x  →  ${ip}"
        done
        # Sauvegarder pour le rapport
        echo "=== TOP IPs ($filename) ===" >> "$ANALYSIS_RESULTS_FILE"
        echo "$top_ips" >> "$ANALYSIS_RESULTS_FILE"
    else
        echo -e "    ${C_YELLOW}Aucune IP trouvee${C_RESET}"
    fi

    # ── Comptage Erreurs HTTP ──
    local count_404 count_500 count_403 count_502
    count_404=$(grep -c " 404 " "$log_file" 2>/dev/null)
    count_500=$(grep -c " 500 " "$log_file" 2>/dev/null)
    count_403=$(grep -c " 403 " "$log_file" 2>/dev/null)
    count_502=$(grep -c " 502 " "$log_file" 2>/dev/null)
    count_404=${count_404:-0}
    count_500=${count_500:-0}
    count_403=${count_403:-0}
    count_502=${count_502:-0}

    echo -e "  ${C_GREEN}Erreurs HTTP:${C_RESET}"
    echo -e "    404 (Not Found)       : ${count_404}"
    echo -e "    403 (Forbidden)       : ${count_403}"
    echo -e "    500 (Server Error)    : ${count_500}"
    echo -e "    502 (Bad Gateway)     : ${count_502}"

    echo "=== ERREURS HTTP ($filename) ===" >> "$ANALYSIS_RESULTS_FILE"
    echo "404: $count_404 | 403: $count_403 | 500: $count_500 | 502: $count_502" >> "$ANALYSIS_RESULTS_FILE"

    # ── Logs des 15 dernieres minutes ──
    echo -e "  ${C_GREEN}Activite (15 dernieres minutes):${C_RESET}"
    local cutoff_time
    cutoff_time=$(date -d '15 minutes ago' '+%d/%b/%Y:%H:%M' 2>/dev/null \
        || date -v-15M '+%d/%b/%Y:%H:%M' 2>/dev/null \
        || echo "")

    if [ -n "$cutoff_time" ]; then
        local recent_count
        recent_count=$(awk -v cutoff="$cutoff_time" '$0 ~ cutoff || $0 > cutoff' "$log_file" 2>/dev/null | wc -l)
        echo -e "    ${recent_count} ligne(s) depuis ${cutoff_time}"

        local recent_errors
        recent_errors=$(awk -v cutoff="$cutoff_time" '$0 ~ cutoff || $0 > cutoff' "$log_file" 2>/dev/null \
            | grep -E " (404|500|403|502) " | head -5)

        if [ -n "$recent_errors" ]; then
            echo -e "    ${C_RED}Erreurs recentes:${C_RESET}"
            echo "$recent_errors" | while IFS= read -r line; do
                echo -e "    ${C_RED}→${C_RESET} $line"
            done
        fi
    fi

    log_event "INFOS" "Fichier analyse: $filename | 404:${count_404} 500:${count_500} 403:${count_403} 502:${count_502}"
}

# ==============================================================================
# ANALYSE D'UN CHUNK (pour Fork)
# ==============================================================================
_analyze_chunk() {
    local chunk_file="$1"
    local result_file="$2"

    local count_404 count_500 top_ips
    count_404=$(grep -c " 404 " "$chunk_file" 2>/dev/null || echo 0)
    count_500=$(grep -c " 500 " "$chunk_file" 2>/dev/null || echo 0)
    top_ips=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$chunk_file" 2>/dev/null \
        | sort | uniq -c | sort -rn | head -5)

    {
        echo "CHUNK: $(basename "$chunk_file")"
        echo "404: $count_404"
        echo "500: $count_500"
        echo "TOP_IPS:"
        echo "$top_ips"
        echo "---"
    } > "$result_file"
}

# ==============================================================================
# FUSIONNER LES ReSULTATS DES CHUNKS FORK
# ==============================================================================
_merge_fork_results() {
    local result_files=("$@")
    local total_404=0 total_500=0

    echo -e "\n  ${C_GREEN}═══ Resultats fusionnes (Fork) ═══${C_RESET}"

    for result_file in "${result_files[@]}"; do
        if [ -f "$result_file" ]; then
            local c404 c500
            c404=$(grep "^404:" "$result_file" | awk -F': ' '{print $2}')
            c500=$(grep "^500:" "$result_file" | awk -F': ' '{print $2}')
            total_404=$(( total_404 + ${c404:-0} ))
            total_500=$(( total_500 + ${c500:-0} ))

            cat "$result_file" >> "$ANALYSIS_RESULTS_FILE"
            rm -f "$result_file"
        fi
    done

    echo -e "  Total 404 : ${total_404}"
    echo -e "  Total 500 : ${total_500}"
    log_event "INFOS" "Fusion Fork — Total: 404:${total_404} | 500:${total_500}"
}

# ==============================================================================
# PHASE 3 — CORReLATION COMMANDES ↔ ERREURS
# Compare les timestamps de history.log avec les erreurs des logs service
# C'est la fonctionnalite UNIQUE de BLACKBOX
# ==============================================================================
_phase_correlation() {
    local service="$1"
    local log_path="$2"

    echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_YELLOW}  PHASE 3 — Correlation Commandes ↔ Erreurs ⭐${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"

    # Verifier si history.log existe
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "  ${C_YELLOW}[!] Aucun history.log trouve — Correlation impossible${C_RESET}"
        echo -e "  ${C_YELLOW}[!] Lancez d'abord: blackbox -w $service${C_RESET}"
        log_event "WARN" "Correlation ignoree — history.log introuvable"
        return
    fi

    # Extraire les commandes enregistrees par Dev 1 (mode -w)
    local cmd_lines
    mapfile -t cmd_lines < <(grep " : CMD : " "$LOG_FILE" 2>/dev/null)

    if [ ${#cmd_lines[@]} -eq 0 ]; then
        echo -e "  ${C_YELLOW}[!] Aucune commande enregistree dans history.log${C_RESET}"
        log_event "WARN" "Aucune commande CMD trouvee dans history.log pour correlation"
        return
    fi

    echo -e "  ${C_CYAN}${#cmd_lines[@]} commande(s) enregistree(s) trouvee(s)${C_RESET}"
    echo -e "  ${C_CYAN}Recherche de correlations avec les erreurs du service $service...${C_RESET}\n"

    local corr_count=0
    export CORR_RESULTS_FILE="/tmp/blackbox_corr_$$.txt"
    : > "$CORR_RESULTS_FILE"

    # Pour chaque commande enregistree dans history.log
    for cmd_line in "${cmd_lines[@]}"; do
        # Format: 2026-04-21-02-17-43 : polo : CMD : systemctl restart nginx
        local cmd_ts cmd_user cmd_text
        cmd_ts=$(echo "$cmd_line" | awk -F' : ' '{print $1}' | xargs)
        cmd_user=$(echo "$cmd_line" | awk -F' : ' '{print $2}' | xargs)
        cmd_text=$(echo "$cmd_line" | awk -F' : CMD : ' '{print $2}' | xargs)

        # Convertir le timestamp CMD en secondes epoch
        local cmd_epoch
        cmd_epoch=$(_ts_to_epoch "$cmd_ts")
        [ -z "$cmd_epoch" ] && continue

        # Chercher des erreurs dans les logs du service dans la fenêtre de temps
        local error_found
        error_found=$(_find_errors_near_timestamp "$log_path" "$cmd_epoch" "$DANGER_THRESHOLD")

        if [ -n "$error_found" ]; then
            corr_count=$(( corr_count + 1 ))
            local diff_sec
            diff_sec=$(echo "$error_found" | awk '{print $1}')
            local error_msg
            error_msg=$(echo "$error_found" | cut -d' ' -f2-)

            echo -e "  ${C_BRED}⚠ CORReLATION DeTECTeE:${C_RESET}"
            echo -e "    ${C_GREEN}→ a ${cmd_ts}${C_RESET}"
            echo -e "    ${C_GREEN}→ ${cmd_user} a execute: ${cmd_text}${C_RESET}"
            echo -e "    ${C_RED}→ ${diff_sec}s plus tard: ${error_msg}${C_RESET}"
            echo -e "    ${C_YELLOW}→ CAUSE PROBABLE IDENTIFIeE${C_RESET}\n"

            # ecrire dans history.log (type CORR)
            local corr_msg="${cmd_text} → [+${diff_sec}s] ${error_msg}"
            log_event "CORR" "$corr_msg"

            # Sauvegarder pour le rapport
            echo "CORRELATION: $cmd_ts | USER:$cmd_user | CMD:$cmd_text | ERROR:[+${diff_sec}s] $error_msg" \
                >> "$CORR_RESULTS_FILE"
        fi
    done

    if [ "$corr_count" -eq 0 ]; then
        echo -e "  ${C_GREEN}✓ Aucune correlation suspecte detectee${C_RESET}"
        log_event "INFOS" "Correlation terminee — Aucun incident detecte"
    else
        echo -e "  ${C_RED}✗ ${corr_count} correlation(s) suspecte(s) detectee(s)${C_RESET}"
        log_event "INFOS" "Correlation terminee — ${corr_count} incident(s) identifie(s)"
    fi
}

# ==============================================================================
# CONVERTIR TIMESTAMP blackbox → EPOCH SECONDES
# Format: 2026-04-21-02-17-43 → secondes depuis epoch
# ==============================================================================
_ts_to_epoch() {
    local ts="$1"
    # Format: YYYY-MM-DD-HH-MM-SS
    local formatted
    formatted=$(echo "$ts" | sed 's/\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
    date -d "$formatted" "+%s" 2>/dev/null || echo ""
}

# ==============================================================================
# CHERCHER DES ERREURS DANS LES LOGS PROCHES D'UN TIMESTAMP
# ==============================================================================
_find_errors_near_timestamp() {
    local log_path="$1"
    local cmd_epoch="$2"
    local threshold="$3"

    local log_files
    mapfile -t log_files < <(find "$log_path" -maxdepth 2 -type f -name "*.log" 2>/dev/null)

    for log_file in "${log_files[@]}"; do
        # Chercher des lignes d'erreur dans le fichier
        while IFS= read -r error_line; do
            # Extraire le timestamp de la ligne d'erreur
            # Formats courants nginx: 2026/04/21 02:17:45
            # Format apache: [Mon Apr 21 02:17:45.000 2026]
            local err_epoch
            err_epoch=$(_extract_log_timestamp "$error_line")
            [ -z "$err_epoch" ] && continue

            local diff=$(( err_epoch - cmd_epoch ))

            # Si l'erreur est dans la fenêtre [0, threshold] secondes apres la commande
            if [ "$diff" -ge 0 ] && [ "$diff" -le "$threshold" ]; then
                local short_error
                short_error=$(echo "$error_line" | cut -c1-100)
                echo "$diff $short_error"
                return 0
            fi
        done < <(grep -iE "(error|crit|alert|emerg|500|502|503)" "$log_file" 2>/dev/null | head -100)
    done

    echo ""
}

# ==============================================================================
# EXTRAIRE LE TIMESTAMP D'UNE LIGNE DE LOG
# ==============================================================================
_extract_log_timestamp() {
    local line="$1"
    local epoch=""

    # Format nginx: 2026/04/25 20:31:06
    if echo "$line" | grep -qE '[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        local raw cleaned
        raw=$(echo "$line" | grep -oE '[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
        cleaned=$(echo "$raw" | sed 's|/|-|g')
        epoch=$(date -d "$cleaned" "+%s" 2>/dev/null || echo "")

    # Format apache: [21/Apr/2026:02:17:45
    elif echo "$line" | grep -qE '\[[0-9]{2}/[A-Za-z]{3}/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        local raw cleaned
        raw=$(echo "$line" | grep -oE '[0-9]{2}/[A-Za-z]{3}/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
        cleaned=$(echo "$raw" | sed 's|/| |g' | sed 's/:/ /' )
        epoch=$(date -d "$cleaned" "+%s" 2>/dev/null || echo "")

    # Format syslog: Apr 21 02:17:45
    elif echo "$line" | grep -qE '[A-Za-z]{3} +[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        local raw
        raw=$(echo "$line" | grep -oE '[A-Za-z]{3} +[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
        epoch=$(date -d "$raw" "+%s" 2>/dev/null || echo "")
    fi

    echo "$epoch"
}

# ==============================================================================
# PHASE 4 — GeNeRATION DU RAPPORT COMPRESSe
# ==============================================================================
_phase_generate_report() {
    local service="$1"
    local ts
    ts=$(date "+%Y-%m-%d_%H-%M-%S")
    local report_name="${ts}_${service}_report"
    local report_txt="/tmp/${report_name}.txt"
    local archive_path="${ARCHIVE_DIR}/${report_name}.tar.gz"

    echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_YELLOW}  PHASE 4 — Generation du Rapport${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"

    # Creer le rapport texte
    {
        echo "============================================================"
        echo "  BLACKBOX — Rapport d'Analyse Forensique"
        echo "  Service  : $service"
        echo "  Date     : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Genere   : $(whoami)@$(hostname)"
        echo "============================================================"
        echo ""

        echo "── PROFILAGE SYSTeME ──"
        echo "CPU Usage   : $(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8"%"}')"
        echo "RAM         : $(free -m | awk '/^Mem:/{print $3"MB/"$2"MB"}')"
        echo "Disque (/)  : $(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')"
        echo "Load Avg    : $(uptime | awk -F'load average:' '{print $2}')"
        echo ""

        echo "── ANALYSE DES LOGS ──"
        if [ -f "$ANALYSIS_RESULTS_FILE" ]; then
            cat "$ANALYSIS_RESULTS_FILE"
        fi
        echo ""

        echo "── CORReLATIONS DeTECTeES ──"
        if [ -f "$CORR_RESULTS_FILE" ]; then
            cat "$CORR_RESULTS_FILE"
        else
            echo "Aucune correlation enregistree."
        fi
        echo ""

        echo "============================================================"
        echo "  Fin du rapport — BLACKBOX v1.0"
        echo "============================================================"
    } > "$report_txt"

    # ── Compression du rapport ──
    mkdir -p "$ARCHIVE_DIR"

    if [ "$FLAG_THREAD" = true ]; then
        # Utilisation du helper C multithreade (Exigence -t)
        local helper="./bin/compress_helper"
        if [ -x "$helper" ]; then
            log_event "INFOS" "Compression multithreadee du rapport avec $helper"
            if "$helper" -j 4 "$archive_path" "$report_txt"; then
                 log_event "INFOS" "Rapport compresse via Thread (C) ✓"
            else
                 log_event "ERROR" "echec compression multithread. Repli sur tar."
                 tar -czf "$archive_path" -C /tmp "${report_name}.txt" 2>/dev/null
            fi
        else
            log_event "WARN" "Helper C introuvable. Repli sur tar standard."
            tar -czf "$archive_path" -C /tmp "${report_name}.txt" 2>/dev/null
        fi
    else
        # Compression standard (tar)
        tar -czf "$archive_path" -C /tmp "${report_name}.txt" 2>/dev/null
    fi

    if [ -f "$archive_path" ]; then
        echo -e "  ${C_GREEN}✓ Rapport genere:${C_RESET}"
        echo -e "    ${archive_path}"
        local size
        size=$(du -h "$archive_path" | awk '{print $1}')
        echo -e "    Taille: ${size}"
        log_event "INFOS" "Rapport genere: $archive_path ($size)"
    else
        log_event "ERROR" "echec de la generation du rapport compresse"
    fi

    # Nettoyage fichiers temporaires
    rm -f "$report_txt" "$ANALYSIS_RESULTS_FILE" "$CORR_RESULTS_FILE" 2>/dev/null
}