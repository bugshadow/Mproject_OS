# BLACKBOX — Boite Noire pour Serveurs Linux
**Projet Module SE 2025/2026 — ENSET Mohammedia**

Bienvenue sur le depot du projet blackbox. Ce README explique l'architecture du projet, le role de chaque developpeur et les instructions d'utilisation pour le travail en equipe.

---

## Architecture du Projet

L'architecture (realisee par Dev 1) est modulaire. Le point d'entree est le script "blackbox" a la racine. Le code defini pour chaque tache est decoupe dans le dossier "src/".
```text
Mproject_OS/
|-- blackbox                 # Point d'entree (Squelette + Getopts) 
|-- src/                     # Code metier pour chaque mode
|   |-- utils.sh             # Fonctions partagees : log_event(), die(), cleanup()
|   |-- mode_watch.sh        # Code Dev 1 : Mode -w (Termine)
|   |-- mode_analyze.sh      # Code Dev 2 : Mode -a (Stub a remplir)
|   |-- mode_playback.sh     # Code Dev 3 : Mode -p (Stub a remplir)
|-- bin/                     # Dossier pour le programme C compile (Dev 3)
|-- tests/                   
|   |-- test_environment.sh  # Script pour generer des logs artificiels (small/medium/large)
|-- var/log/blackbox/        # Dossier de stockage des logs generes par blackbox
```

---

## Repartition des Taches

### [Dev 1 : Core Architecture Lead] - Omar (Termine)
**Ce qui a ete accompli :**
- Script Principal (blackbox) : Gere de tous les arguments (-h, -w, -a, -p, etc.). 
- Utilitaires (src/utils.sh) : Fonction log_event formatee et atomique (flock).
- Mode Watch (src/mode_watch.sh) : Le mode -w avec interception des commandes via PROMPT_COMMAND, avertissements de commandes dangereuses (rm -rf /) et un snapshot systeme RAM/CPU.
- Makefile : Creation du Makefile qui donne automatiquement les droits d'execution et prepare le projet.

### [Dev 2 : Analysis & Forensics] - (A faire)
**Objectif :** Implementer le mode -a (Analyze) et l'option -f (Fork).
- Fichier a modifier : src/mode_analyze.sh
- Mission : 
  - Analyser les logs systeme du service.
  - Extraire les IP uniques, compter les erreurs 4xx/5xx sur les 15 dernieres minutes.
  - Implementer le multithreading via l'option -f (decouper un gros fichier log avec split et lancer des processus enfants en arriere-plan).
  - Utiliser log_event pour chaque message systeme.

### [Dev 3 : C Helper & System Integration] - (A faire)
**Objectif :** Implementer le mode -p (Playback) et l'option -t (Thread C).
- Fichiers a modifier : src/mode_playback.sh et creation du helper en C (compress_helper.c)
- Mission : 
  - Dans src/mode_playback.sh, configurer la logique du mode -p : lire le fichier history.log ligne par ligne et attendre "Entree" pour avancer.
  - Creer compress_helper.c (outil de compression multithread).
  - Mettre a jour le Makefile si besoin pour la compilation du C vers le dossier bin/.

---

## Instructions d'utilisation

1. Configurer l'environnement :
Pour attribuer automatiquement les droits d'execution (chmod +x) et compiler le projet, tapez simplement cette commande :
```bash
make
```

2. Afficher l'aide du programme :
```bash
./blackbox -h
```

3. Tester le Mode Watch (Dev 1) localement dans un sous-shell :
L'option -l permet de stocker les logs de test dans un dossier local pour eviter d'avoir besoin de modifier /var/.
```bash
./blackbox -l ./var/log/blackbox -s -w nginx
```

Regle de codage pour Dev 2 et Dev 3 :
N'utilisez pas "echo" pour l'affichage, servez-vous de la fonction existante stockee dans utils.sh :
```bash
log_event "INFOS" "Je commence l'analyse..."
log_event "ERROR" "Fichier introuvable"
```
