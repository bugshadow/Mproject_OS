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

### [Dev 2 : Analysis & Forensics] - (Termine)
**Objectif :** Implementer le mode -a (Analyze) et l'option -f (Fork).
- Fichier modifie : src/mode_analyze.sh
- Mission accomplie : 
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

---

## 🚀 Guide de Test Ultra-Détaillé (Spécial Évaluation / Kali Linux)

Voici toutes les commandes ultra-détaillées (step-by-step) pour prouver au professeur le bon fonctionnement global de `blackbox`, ligne par ligne, avec les comportements attendus.

### Étape 1 : Préparation du Terrain
On télécharge le projet, donne les droits avec Makefile, et on génère les faux logs nécessaires aux tests d'analyse :
```bash
git clone https://github.com/bugshadow/Mproject_OS.git
cd Mproject_OS
make
./tests/generate_test_logs.sh
```

### Étape 2 : Vérification de l'Interface et la Gestion d'Erreur (Codes 100 à 104)
Le script doit rejeter les mauvaises manipulations et afficher l'aide AVANT d'afficher la grosse boîte d'erreur rouge :
```bash
# Vérifier l'aide détaillée classique
./blackbox -h

# Tester une option inconnue :
./blackbox --unknown
# 👉 Affichera l'aide, puis la grosse box "❌ ERREUR 100 : Option inconnue"

# Tester le service manquant :
./blackbox -w
# 👉 Affichera l'aide, puis la grosse box "❌ ERREUR 101 : Paramètre obligatoire manquant"

# Tester les droits super-admin/permission :
./blackbox -w sshd
# 👉 Affichera l'aide, puis la grosse box "❌ ERREUR 103 : Permission refusée. [...] Utilisez sudo"

# Tester le dossier log manquant :
./blackbox -a servicenontrouve
# 👉 Affichera l'aide, puis la grosse box "❌ ERREUR 102 : Répertoire source introuvable [...]"
```

### Étape 3 : Preuve de la Boîte Noire et Multi-Utilisateurs (Mode Watch: -w -s)
Nous allons lancer Blackbox en sous-shell (arrière-plan), puis créer un faux hacker pour s'y connecter et enregistrer ses commandes :
```bash
# Lancement de blackbox (droits root nécessaires pour le hook /etc/profile.d)
sudo ./blackbox -s -w sshd

# OUVREZ UN DEUXIÈME TERMINAL (pour simuler une connexion d'un autre utilisateur/hacker) :
sudo useradd -m testuser
sudo su - testuser

# (Dans ce 2ème terminal, en tant que testuser) - Frappons des commandes :
ls -la /
whoami
echo "rm -rf /" # (On n'exécute pas un VRAI rm, mais le regex le reconnaîtra comme commande dangereuse !)
exit # On ferme la session testuser
```

👉 **Retournez dans le PREMIER terminal et vérifiez l'Enregistrement :**
```bash
sudo cat /var/log/blackbox/history.log
```
*Travail Attendu :* Vous verrez la date précise, le nom `testuser`, les commandes qu'il a tapées (`ls`, `whoami`), ainsi qu'un immense bloc rouge **DANGER** lié au mot `rm -rf /`. De plus, chaque commande est accompagnée d'un tag **SNAP** montrant l'état précis du CPU/RAM à la milliseconde près !

### Étape 4 : Preuve de l'Analyse Forensique (Mode Analyze: -a)
Blackbox va maintenant scanner vos archives `/var/log` et surtout le dossier `./tests/sample_logs/` qu'on vient de générer.
```bash
sudo ./blackbox -a nginx
```
*Travail Attendu :*
- **Phase 1** : Il affiche un bilan santé du système actuel (CPU, RAM).
- **Phase 2** : Il lit le `nginx_access_small.log` généré.
- **Phase Finale** : Il trouve des IP uniques (192.168.1.10, 8.8.8.8, etc.), compte les erreurs (404, 500, 502) et génère une archive`.tar.gz` du rapport.

👉 **Vérification du rapport :**
```bash
ls -lh /var/log/blackbox/archives/
# Ou visualiser l'intérieur (remplacez par le vrai nom du .gz généré) :
tar -xzf /var/log/blackbox/archives/*_nginx_report.tar.gz -O | less
```

### Étape 5 : Preuve de la Performance "Multiprocessing" (Mode Fork: -f)
Pour scanner de très gros logs sans figer le système, on utilise la commande Linux `split` et la gestion de processus en arrière-plan `&`.
```bash
# Ouvrir 2 terminaux :
# Terminal 1 (Optionnel, pour espionner le processeur) :
watch -n 0.5 'ps faux | grep blackbox'

# Terminal 2 (Le vrai test en mode Fork sur nginx) :
sudo ./blackbox -f -a nginx
```
*Travail Attendu :* Grâce à l'option `-f`, Blackbox détecte que `nginx_access_large.log` et `nginx_access_medium.log` font plus de 100 Mo. Il va les diviser en morceaux et créer plusieurs "Processus Enfants (PID)" simultanés pour les résoudre 4 fois plus vite ! C'est la validation finale du cahier des charges (Système d'Exploitation : Processus).

### Étape 6 : Preuve de Nettoyage (Mode Restore: -r)
Une fois la présentation au professeur terminée, il faut nettoyer le serveur.
```bash
sudo ./blackbox -r
```
*Travail Attendu :* Tous les hooks (`/etc/profile.d`), le dossier `/var/log/blackbox` et les `.bash_history` infectés seront proprement supprimés.

---

Regle de codage pour Dev 2 et Dev 3 :
N'utilisez pas "echo" pour l'affichage, servez-vous de la fonction existante stockee dans utils.sh :
```bash
log_event "INFOS" "Je commence l'analyse..."
log_event "ERROR" "Fichier introuvable"
```
