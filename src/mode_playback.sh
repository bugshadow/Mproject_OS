#!/bin/bash

# ==============================================================================
# MODE PLAYBACK : Rejeu de Session (Rôle de Dev 3)
# ==============================================================================

playback_main() {
    local service="$1"
    local target_date="$2"
    log_event "INFOS" "Mode Playback appelé pour $service à la date : $target_date"
    
    # //////////////////////////////////////////////////
    # TODO Dev 3: 
    # Mettre ici la logique pour lire le fichier history.log
    # et filtrer pas-à-pas
    # //////////////////////////////////////////////////
    
    log_event "INFOS" "[Stub] Logique de rejeu en attente de Dev 3."
}
