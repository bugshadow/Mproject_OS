#!/bin/bash

# ==============================================================================
# SCRIPT DE TEST : Validation du Watch Mode (Blackbox) - MODE LOCAL SÉCURISÉ
# ==============================================================================
# Ce script prépare l'environnement pour tester manuellement le Watch Mode
# SANS toucher au système d'exploitation réel (/var/log). Tout reste local.
# ==============================================================================

# Couleurs
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}=== Préparation de l'environnement de test local ===${NC}"

# 1. Création d'un faux service "testapp" dans ./tests/sample_logs
echo -e "${YELLOW}[1] Création du faux service 'testapp' dans ./tests/sample_logs/testapp...${NC}"
mkdir -p ./tests/sample_logs/testapp
touch ./tests/sample_logs/testapp/error.log
chmod 777 ./tests/sample_logs/testapp/error.log
echo -e "${GREEN}Fichier ./tests/sample_logs/testapp/error.log créé.${NC}"

# 2. Création d'un répertoire pour les logs de Blackbox
echo -e "${YELLOW}[2] Création du dossier local ./var/log pour history.log...${NC}"
mkdir -p ./var/log
echo -e "${GREEN}Dossier ./var/log prêt.${NC}"

echo ""
echo -e "${CYAN}=== INSTRUCTIONS DE TEST MANUEL ===${NC}"
echo -e "Pour tester le Watch Mode en toute sécurité, ouvrez DEUX terminaux."
echo ""
echo -e "${YELLOW}TERMINAL 1 : Lancement du Watch Mode${NC}"
echo "-------------------------------------"
echo "1. Placez-vous à la racine du projet (/kali-stuff/projects/os-project)"
echo "2. Lancez Blackbox avec le dossier de log local (-l ./var/log) :"
echo -e "   ${GREEN}./blackbox -l ./var/log -v -w testapp${NC}"
echo "3. Tapez une commande normale :"
echo -e "   ${GREEN}ls -la${NC}"
echo "   -> Vous devriez voir le log CMD, le log RET et le SNAP (CPU/RAM/Disque)."
echo ""
echo "4. Tapez une commande dangereuse :"
echo -e "   ${GREEN}chmod 777 /etc${NC}"
echo "   -> Vous devriez voir l'Alerte Rouge DANGER s'afficher."
echo ""
echo "5. Laissez ce terminal ouvert, et allez au Terminal 2"
echo ""

echo -e "${YELLOW}TERMINAL 2 : Simulation d'une erreur de service${NC}"
echo "-------------------------------------"
echo "1. Placez-vous à la racine du projet."
echo "2. Dans le Terminal 1, tapez une commande (ex: 'pwd')."
echo "3. Dans les 3 secondes qui suivent, injectez une erreur depuis le Terminal 2 :"
echo -e "   ${GREEN}echo \"[crit] Local database failed\" >> ./tests/sample_logs/testapp/error.log${NC}"
echo "   -> Le Terminal 1 devrait détecter la nouvelle erreur et afficher 'Corrélation détectée'."
echo ""

echo -e "${YELLOW}VÉRIFICATION DU LOG${NC}"
echo "-------------------------------------"
echo "Quand vous avez terminé, tapez 'exit' dans le Terminal 1 pour quitter."
echo "Regardez le contenu du fichier généré :"
echo -e "${GREEN}cat ./var/log/history.log${NC}"
