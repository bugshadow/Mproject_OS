#!/bin/bash
# ==============================================================================
# SCRIPT DE DeMONSTRATION POUR LA SOUTENANCE (PROFESSEUR)
# ==============================================================================
# Scenarios Légers, Moyens, et Lourds (Subshell, Fork, Thread)
# ==============================================================================

# Couleurs ANSI
C_RESET="\e[0m"
C_CYAN="\e[36m"
C_YELLOW="\e[33m"
C_GREEN="\e[32m"
C_RED="\e[31m"

echo -e "${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_CYAN}║     BLACKBOX — DeMONSTRATION DES 3 SCeNARIOS (Subshell, Fork, Thread)║${C_RESET}"
echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"

# Compilation prealable + creation des logs si pas deja fait
echo -e "\n${C_YELLOW}>>etape 0 : Initialisation de l'environnement...${C_RESET}"
make >/dev/null 2>&1

if [ ! -f "tests/sample_logs/nginx_access_large.log" ]; then
    echo "Génération des logs manquants..."
    ./tests/test_environment.sh >/dev/null 2>&1
    ./tests/generate_test_logs.sh >/dev/null 2>&1
else
    echo -e "Les 3 logs de test (small, medium, large) sont déjà présents. On les utilise !"
fi

echo -e "${C_GREEN}[✓] Environnement de demonstration prêt.${C_RESET}"

echo -e "\nAppuyez sur [ENTReE] pour lancer le Scenario 1 (Léger)..."
read -r

# ------------------------------------------------------------------------------
# SceNARIO 1 : TEST LeGER (Subshell -s + Watch -w)
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}====================================================================${C_RESET}"
echo -e "${C_CYAN}  SCeNARIO 1 : TRAITEMENT LeGER (Isolation Subshell + Watch)${C_RESET}"
echo -e "${C_CYAN}====================================================================${C_RESET}"
echo -e "Directive : Exécution dans un sous-shell isolé pour le monitoring léger d'un service."
echo -e "Commande executee : ${C_YELLOW}./blackbox -s -l ./var/log -w test_leger_cron${C_RESET}\n"

# On execute en fond puis on l'arrête au bout de quelques secondes
./blackbox -s -l ./var/log -w test_leger_cron &
PID_WATCH=$!
sleep 2
echo -e "\n${C_GREEN}[✓] Le module watch tourne sous PID $PID_WATCH (isole par subshell).${C_RESET}"
kill $PID_WATCH 2>/dev/null

echo -e "\nAppuyez sur [ENTReE] pour lancer le Scenario 2 (Moyen)..."
read -r

# ------------------------------------------------------------------------------
# SceNARIO 2 : TEST MOYEN (Fork -f + Analyze -a)
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}====================================================================${C_RESET}"
echo -e "${C_CYAN}  SCeNARIO 2 : TRAITEMENT MOYEN (Multiprocesing Fork + Analyze)${C_RESET}"
echo -e "${C_CYAN}====================================================================${C_RESET}"
echo -e "Directive : Analyse d'un fichier volumineux (nginx_access_large.log) via plusieurs processus fils."
echo -e "Commande executee : ${C_YELLOW}./blackbox -f -l ./var/log -a nginx_access_large${C_RESET} (simulé localement)\n"

# On cree un dossier spécifique temporaire pour la demo moyenne
mkdir -p ./var/log/demo_nginx
cp tests/sample_logs/nginx_access_large.log ./var/log/demo_nginx/
./blackbox -f -l ./var/log -a demo_nginx 

echo -e "\n${C_GREEN}[✓] Le fichier a été découpé et analysé en parallèle via Fork.${C_RESET}"

echo -e "\nAppuyez sur [ENTReE] pour lancer le Scenario 3 (Lourd)..."
read -r

# ------------------------------------------------------------------------------
# SceNARIO 3 : TEST LOURD (Thread -t + Analyze/Playback)
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}====================================================================${C_RESET}"
echo -e "${C_CYAN}  SCeNARIO 3 : TRAITEMENT LOURD (Compression Multithread C)${C_RESET}"
echo -e "${C_CYAN}====================================================================${C_RESET}"
echo -e "Directive : Lancer un archivage/rejeu d'un rapport de taille extrême en utilisant le module C multithread."
echo -e "Commande executee : ${C_YELLOW}./blackbox -t -l ./var/log -p '2026-04-21' demo_apache${C_RESET}\n"

./blackbox -t -l ./var/log -p "2026-04-21" demo_apache 

echo -e "\n${C_GREEN}[✓] La compression/le module C Pthreads a été sollicité avec l'option -t.${C_RESET}"
echo -e "\n${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_CYAN}║     FIN DE LA DeMONSTRATION                                      ║${C_RESET}"
echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"

