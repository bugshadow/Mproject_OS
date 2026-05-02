#!/bin/bash

# ==============================================================================
# MODE PLAYBACK : Rejeu de Session (Rôle de Dev 3)
# ==============================================================================
#
# Variables globales implicites utilisées entre les fonctions _playback_* :
#   PB_TS   — Timestamp de l'événement courant (format YYYY-MM-DD-HH-MM-SS)
#   PB_USER — Nom de l'utilisateur ayant exécuté la commande
#   PB_TYPE — Type d'événement (CMD, RET, SNAP, CORR, DANGER, ERROR, INFOS, WARN)
#   PB_MSG  — Contenu/message de l'événement
#
# Ces variables sont positionnées par _playback_parse_line() et lues par
# _playback_print_record(), _playback_is_internal_event(), et playback_main().
# ==============================================================================

_playback_normalize_timestamp() {
    local raw="$1"

    if [[ "$raw" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
        printf "%s-%s-%s-00-00-00\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        return 0
    fi

    if [[ "$raw" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})[_[:space:]]([0-9]{2})[:-]([0-9]{2})[:-]([0-9]{2})$ ]]; then
        printf "%s-%s-%s-%s-%s-%s\n" \
            "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" \
            "${BASH_REMATCH[4]}" "${BASH_REMATCH[5]}" "${BASH_REMATCH[6]}"
        return 0
    fi

    if [[ "$raw" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
        printf "%s\n" "$raw"
        return 0
    fi

    return 1
}

_playback_parse_line() {
    local line="$1"
    local rest

    PB_TS="${line%% : *}"
    [ "$PB_TS" = "$line" ] && return 1

    rest="${line#* : }"
    PB_USER="${rest%% : *}"
    [ "$PB_USER" = "$rest" ] && return 1

    rest="${rest#* : }"
    PB_TYPE="${rest%% : *}"
    [ "$PB_TYPE" = "$rest" ] && return 1

    PB_MSG="${rest#* : }"
    return 0
}

_playback_print_event() {
    local label="$1"
    local color="$2"
    local message="$3"

    printf "    %b%-10s%b %s\n" "$color" "$label" "$C_RESET" "$message"
}

_playback_is_internal_event() {
    [ "$PB_TYPE" != "INFOS" ] && return 1

    case "$PB_MSG" in
        "Mode Playback démarré"*|"Playback terminé"*|"blackbox démarré"*"mode: playback"*)
            return 0
            ;;
    esac

    return 1
}

_playback_pause() {
    [ -t 0 ] || return 0
    printf "%b" "${C_YELLOW}    Appuyez sur Entrée pour avancer...${C_RESET}"
    read -r _
    printf "\n"
}

_playback_print_record() {
    case "$PB_TYPE" in
        CMD)
            local cwd cmd
            cwd="${PB_MSG%% : *}"
            cmd="${PB_MSG#* : }"
            if [ "$cwd" != "$PB_MSG" ]; then
                _playback_print_event "PWD" "$C_BLUE" "$cwd"
                _playback_print_event "CMD" "$C_GREEN" "$cmd"
            else
                _playback_print_event "CMD" "$C_GREEN" "$PB_MSG"
            fi
            ;;
        RET)
            _playback_print_event "RET" "$C_CYAN" "$PB_MSG"
            ;;
        SNAP)
            _playback_print_event "SNAP" "$C_CYAN" "$PB_MSG"
            ;;
        CORR)
            _playback_print_event "CORR" "$C_YELLOW" "$PB_MSG"
            ;;
        DANGER)
            _playback_print_event "DANGER" "$C_BRED" "$PB_MSG"
            ;;
        ERROR)
            _playback_print_event "ERROR" "$C_RED" "$PB_MSG"
            ;;
        INFOS|WARN)
            _playback_print_event "$PB_TYPE" "$C_YELLOW" "$PB_MSG"
            ;;
        *)
            _playback_print_event "$PB_TYPE" "$C_RESET" "$PB_MSG"
            ;;
    esac
}

playback_main() {
    local service="$1"
    local target_date="$2"
    local target_ts
    local line
    local step=1
    local index=0
    local total=0
    local -a playback_lines

    target_ts=$(_playback_normalize_timestamp "$target_date") \
        || die 100 "Format de date invalide pour -p. Utilisez YYYY-MM-DD ou YYYY-MM-DD_HH-MM-SS"

    [ -f "$LOG_FILE" ] || die 104 "Fichier history.log introuvable : $LOG_FILE"

    while IFS= read -r line; do
        _playback_parse_line "$line" || continue
        _playback_is_internal_event && continue
        [[ "$PB_TS" < "$target_ts" ]] && continue
        playback_lines[$total]="$line"
        total=$((total + 1))
    done < "$LOG_FILE"

    log_event "INFOS" "Mode Playback démarré pour $service à partir de : $target_ts"

    if [ "$total" -eq 0 ]; then
        log_event "WARN" "Aucun événement trouvé dans history.log à partir de $target_ts"
        return 0
    fi

    printf "\n%b╔══════════════════════════════════════════════════════╗%b\n" "$C_CYAN" "$C_RESET"
    printf "%b║        BLACKBOX — Playback : %-20.20s ║%b\n" "$C_CYAN" "$service" "$C_RESET"
    printf "%b╚══════════════════════════════════════════════════════╝%b\n\n" "$C_CYAN" "$C_RESET"
    printf "  Rejeu depuis : %s\n" "$target_ts"
    printf "  Source       : %s\n" "$LOG_FILE"
    printf "  Événements   : %s\n\n" "$total"

    while [ "$index" -lt "$total" ]; do
        _playback_parse_line "${playback_lines[$index]}" || {
            index=$((index + 1))
            continue
        }

        printf "%b[Étape %03d]%b %s — utilisateur: %s\n" "$C_GREEN" "$step" "$C_RESET" "$PB_TS" "$PB_USER"
        _playback_print_record
        index=$((index + 1))

        while [ "$index" -lt "$total" ]; do
            _playback_parse_line "${playback_lines[$index]}" || {
                index=$((index + 1))
                continue
            }

            [ "$PB_TYPE" = "CMD" ] && break
            _playback_print_record
            index=$((index + 1))
        done

        _playback_pause
        step=$((step + 1))
    done

    log_event "INFOS" "Playback terminé — $total événement(s) rejoué(s)"

    # ── Compression via le helper C si -t est activé ──
    if [ "$FLAG_THREAD" = true ]; then
        _playback_compress_log
    fi
}

# ==============================================================================
# COMPRESSION DU LOG VIA LE HELPER C MULTITHREADÉ (Option -t)
# ==============================================================================
_playback_compress_log() {
    local helper="./bin/compress_helper"

    if [ ! -x "$helper" ]; then
        log_event "WARN" "compress_helper introuvable ou non exécutable. Lancez 'make' d'abord."
        return 1
    fi

    local ts
    ts=$(date "+%Y-%m-%d_%H-%M-%S")
    local archive_name="${ts}_playback_history.tar.gz"
    local output_path="${ARCHIVE_DIR}/${archive_name}"

    mkdir -p "$ARCHIVE_DIR"

    log_event "INFOS" "Compression multithread de $LOG_FILE → $output_path"

    if "$helper" -j 4 "$output_path" "$LOG_FILE"; then
        local size
        size=$(du -h "$output_path" 2>/dev/null | awk '{print $1}')
        log_event "INFOS" "Archive compressée créée : $output_path ($size)"
        printf "  %b✓ Archive compressée :%b %s (%s)\n" "$C_GREEN" "$C_RESET" "$output_path" "$size"
    else
        log_event "ERROR" "Échec de la compression de $LOG_FILE"
        return 1
    fi
}
