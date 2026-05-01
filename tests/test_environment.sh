#!/bin/bash

# Configuration des couleurs
C_RESET="\e[0m"
C_GREEN="\e[32m"
C_BLUE="\e[34m"
C_CYAN="\e[36m"

TEST_DIR="tests/sample_logs"
VAR_DIR="var/log/blackbox/archives"

echo -e "${C_CYAN}[▶] Initialisation de l'environnement de test...${C_RESET}"

# Création des répertoires
mkdir -p "$TEST_DIR"
mkdir -p "$VAR_DIR"

echo -e "${C_BLUE}[i] Génération de nginx_access_small.log (~100 KB)...${C_RESET}"
head -c 100000 /dev/urandom | base64 > "$TEST_DIR/nginx_access_small.log"

echo -e "${C_BLUE}[i] Génération de nginx_access_medium.log (~50 MB)...${C_RESET}"
head -c 50000000 /dev/urandom | base64 > "$TEST_DIR/nginx_access_medium.log"

echo -e "${C_BLUE}[i] Génération de nginx_access_large.log (~200 MB)...${C_RESET}"
head -c 200000000 /dev/urandom | base64 > "$TEST_DIR/nginx_access_large.log"

echo -e "${C_GREEN}[✓] Environnement de test prêt !${C_RESET}"
