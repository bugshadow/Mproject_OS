#!/bin/bash

# ==============================================================================
# Script de test pour l'alerte SMS (Twilio)
# ==============================================================================

# Se placer à la racine du projet
cd "$(dirname "$0")/.." || exit 1

echo -e "\e[1;34m==================================================\e[0m"
echo -e "\e[1;34m          TEST DE L'ALERTE SMS TWILIO\e[0m"
echo -e "\e[1;34m==================================================\e[0m"

# 1. Vérification du fichier .env
if [ ! -f "./.env" ]; then
    echo -e "\e[1;31m[✗] ERREUR : Le fichier .env est introuvable à la racine du projet.\e[0m"
    exit 1
fi

source "./.env"

# 2. Vérification des variables Twilio
if [ -z "$TWILIO_ACCOUNT_SID" ] || [ -z "$TWILIO_AUTH_TOKEN" ] || [ -z "$TWILIO_FROM_NUMBER" ] || [ -z "$TWILIO_TO_NUMBER" ]; then
    echo -e "\e[1;31m[✗] ERREUR : Les variables Twilio sont incomplètes dans '.env'.\e[0m"
    echo -e "\e[1;37mVérifiez TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER et TWILIO_TO_NUMBER.\e[0m"
    exit 1
fi

echo -e "\e[1;36m[i] Configuration trouvée :\e[0m"
echo "  - Account SID : $TWILIO_ACCOUNT_SID"
echo "  - From (Exp)  : $TWILIO_FROM_NUMBER"
echo "  - To (Dest)   : $TWILIO_TO_NUMBER"
echo ""
echo -e "\e[1;33m[i] Envoi du SMS via Twilio... (Patientez)\e[0m"

# 3. Envoi de la requête API Twilio
cmd_intercepted="test_sms_blackbox_ok"

# Envoi du SMS
response=$(curl -s -X POST "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages.json" \
    --data-urlencode "Body=🚨 [BLACKBOX TEST] 🚨
Système de surveillance OK.
Cmd simulée : $cmd_intercepted
Utilisateur : $USER" \
    --data-urlencode "From=$TWILIO_FROM_NUMBER" \
    --data-urlencode "To=$TWILIO_TO_NUMBER" \
    -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN")

echo -e "\n\e[1;36m[Réponse API] :\e[0m"
echo "$response" | grep -oE '"status": "[^"]+"' || echo "$response"

echo -e "\n\e[1;34m==================================================\e[0m"
echo -e "\e[1;32m[✓] Fin de la requête API Twilio.\e[0m"
echo -e "\e[1;37mSi vous voyez \"status\": \"queued\" ou \"sent\", le SMS arrive !\e[0m"
echo -e "\e[1;37mNote : En mode Sandbox, le numéro de destination doit être vérifié sur Twilio.\e[0m"
