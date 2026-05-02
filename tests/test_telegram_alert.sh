#!/bin/bash

# ==============================================================================
# Script de test pour l'alerte Telegram
# ==============================================================================

# Se placer à la racine du projet
cd "$(dirname "$0")/.." || exit 1

echo -e "\e[1;34m==================================================\e[0m"
echo -e "\e[1;34m        TEST DE L'ALERTE TELEGRAM\e[0m"
echo -e "\e[1;34m==================================================\e[0m"

# 1. Vérification du fichier .env
if [ ! -f "./.env" ]; then
    echo -e "\e[1;31m[✗] ERREUR : Le fichier .env est introuvable à la racine du projet.\e[0m"
    exit 1
fi

source "./.env"

# 2. Vérification des variables
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo -e "\e[1;31m[✗] ERREUR : Le TELEGRAM_BOT_TOKEN ou le TELEGRAM_CHAT_ID est vide dans '.env'.\e[0m"
    echo -e "\e[1;33m[i] N'oublie pas d'envoyer un message à ton bot avant de lire l'ID !\e[0m"
    exit 1
fi

echo -e "\e[1;36m[i] Configuration trouvée :\e[0m"
echo "  - Bot Token : $TELEGRAM_BOT_TOKEN"
echo "  - Chat ID   : $TELEGRAM_CHAT_ID"
echo ""
echo -e "\e[1;33m[i] Envoi de l'alerte vers Telegram... (Patientez)\e[0m"

# 3. Envoi synchrone de la requête
cmd_intercepted="commande_test_fictive_telegram"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d parse_mode="HTML" \
    --data-urlencode "text=� <b>TEST BLACKBOX RÉUSSI</b> 🟢
<i>Test du Système de Notification</i>
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖

💎 <b>Statut de l'API :</b> <code>CONNECTÉ</code>
📡 <b>Serveur :</b> Opérationnel

📋 <b>VÉRIFICATION DE L'ENVIRONNEMENT</b>
👤 <b>Testé par :</b> <code>$USER</code>
💻 <b>Machine :</b> <code>$(hostname)</code>
📂 <b>Lancé depuis :</b> <code>$PWD</code>
🕒 <b>Heure locale :</b> <code>$(date '+%Y-%m-%d %H:%M:%S')</code>

🔌 <b>SIMULATION DE COMMANDE :</b>
<pre><code class=\"language-bash\">$cmd_intercepted</code></pre>

✨ <i>Excellent travail pour votre projet d'ingénierie OS !</i>"

echo -e "\n\n\e[1;34m==================================================\e[0m"
echo -e "\e[1;32m[✓] Requête terminée.\e[0m"
echo -e "\e[1;37mAnalysez le texte (JSON) renvoyé par Telegram au-dessus :\e[0m"
echo " - Si le ok: true s'affiche, tu as dû recevoir la notification sur ton téléphone !"
echo " - Sinon, vérifie que le CHAT_ID est le bon."
