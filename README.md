# ✈️ Blackbox — La Boîte Noire pour Serveurs Linux

> **"Parce que chaque crash mérite une enquête."**  
> Un outil Bash robuste pour l'enregistrement, la corrélation et le rejeu d'incidents système.

---

## 🌑 Pourquoi Blackbox ?

### 🚨 Le Scénario du Cauchemar
Il est **02:17 du matin**. Le serveur de production tombe. 50 000 utilisateurs sont bloqués. Le patron appelle. L'administrateur système se connecte et fait face au chaos :
*   Des milliers de lignes de logs éparpillées sans contexte.
*   Un historique `history` sans horodatage précis, facilement effaçable par un attaquant.
*   Aucun moyen de savoir quel utilisateur a tapé quelle commande au moment exact où la RAM a saturé à 99%.

**Blackbox résout cela.** Il agit comme l'enregistreur de vol d'un avion : il capture les actions humaines, l'état de la machine (Snapshots) et les erreurs système (Corrélation), puis permet de **rejouer la scène** (Playback) pour identifier la cause en 5 minutes au lieu de 6 heures.

### 🎯 Public Cible
*   **Administrateurs Système** : Pour identifier la cause d'un crash sans perdre d'heures.
*   **Équipes DevOps / SRE** : Pour l'audit de conformité et la preuve de modification.
*   **Responsables Sécurité** : Pour détecter les intrusions et les commandes dangereuses (`rm -rf`, `chmod 777`).
*   **Étudiants / Stagiaires** : Pour apprendre de leurs erreurs en rejouant leurs sessions de test.

---

## 🛠️ Installation et Préparation du Terrain

```bash
# 1. Récupérer le projet
git clone https://github.com/bugshadow/Mproject_OS.git
cd Mproject_OS

# 2. Configurer les permissions et compiler le helper C (Directives 3.2.2 & Makefile)
make

# 3. Générer les logs de test réalistes (Indispensable pour la démonstration)
./tests/generate_test_logs.sh
```

---

## 🛡️ Focus Technique : Le Mode Watch & Surveillance Multi-Utilisateurs

C'est ici que Blackbox devient un véritable outil de **Cyber-Sécurité**. Contrairement à la commande `history` classique, Blackbox est conçu pour l'audit permanent.

### 1. Incorruptibilité des preuves
Lorsqu'un administrateur lance `sudo ./blackbox -w <service>`, le script installe un **Hook Système** dans `/etc/profile.d/blackbox-watch.sh`. 
*   **Principe** : Chaque utilisateur qui se connecte au serveur est immédiatement "mis sous écoute" par le système.
*   **Résilience** : Même si un pirate tente d'effacer ses traces avec `history -c` ou en supprimant son fichier `~/.bash_history`, **Blackbox a déjà sécurisé la preuve** dans `/var/log/blackbox/history.log`. Ce fichier appartient à **Root**, ce qui le rend impossible à modifier ou supprimer par un utilisateur standard.

### 2. Moteur de Détection "DANGER" (Regex)
Blackbox scanne chaque commande en temps réel grâce à un moteur de filtrage par expressions régulières (Regex).
*   **Patterns critiques détectés** : 
    *   `rm -rf /` : Tentative de destruction totale du système.
    *   `chmod 777` : Tentative d'ouverture de brèches de sécurité.
    *   `mkfs.*` / `dd if=.* of=/dev/sd` : Tentatives de formatage ou destruction de disques.
*   **Résultat** : Une alerte de type `DANGER` est instantanément journalisée avec l'identité de l'utilisateur, permettant une réaction immédiate.

### 3. Workflow de Test Multi-Utilisateurs
Voici comment prouver cette capacité de surveillance globale lors de votre démonstration :

1.  **Terminal 1 (Admin)** : Lancez la surveillance.
    ```bash
    sudo ./blackbox -w sshd
    ```
2.  **Terminal 2 (Le "Hacker")** : Simulez une intrusion.
    ```bash
    # Créer un utilisateur test et forcer l'usage de Bash
    sudo useradd -m testuser && sudo usermod -s /bin/bash testuser
    sudo su - testuser
    
    # Taper des commandes suspectes
    ls -la /root
    echo "rm -rf /"
    exit
    ```
3.  **Terminal 1 (Admin)** : Vérifiez la capture.
    ```bash
    sudo cat /var/log/blackbox/history.log
    ```
    *Vous verrez apparaître le nom `testuser`, ses commandes, et le flag rouge **DANGER**.*

---

## 🧪 Scénarios de Test Certifiés (Démonstration Professeur)

Le cahier des charges exige la démonstration de l'efficacité via 3 scénarios (Léger, Moyen, Lourd) :

### 🟢 Scénario 1 : Traitement Léger (Subshell `-s` + Watch `-w`)
**Objectif** : Valider l'isolation des processus dans un sous-shell.
```bash
# Utiliser -l pour un test local sans droits root
./blackbox -l ./var/log/blackbox -s -w nginx
```
*   **Action** : Tapez `ls`, `pwd`, `whoami`.
*   **Vérification** : Le script tourne dans un environnement `( )` isolé (PID différent). Tapez `exit` pour quitter.

### 🟡 Scénario 2 : Traitement Moyen (Fork `-f` + Analyze `-a`)
**Objectif** : Valider le multiprocessing (fork) sur des logs de taille moyenne.
```bash
./blackbox -l ./var/log/blackbox -f -a nginx
```
*   **Action** : Observez comment Blackbox détecte les fichiers volumineux et crée des processus enfants.
*   **Vérification** : Dans un 2ème terminal, tapez `ps faux | grep blackbox` pour voir les processus parallèles.

### 🔴 Scénario 3 : Traitement Lourd (Thread `-t` + Playback `-p`)
**Objectif** : Valider l'utilisation de threads Pthreads (C) et le rejeu de session.
```bash
# 1. Analyse avec compression multithreadée via le helper C
./blackbox -l ./var/log/blackbox -t -a nginx

# 2. Rejeu de la session (le "Film" du crash)
./blackbox -l ./var/log/blackbox -p 2026-05-01
```
*   **Action** : Appuyez sur `Entrée` pour avancer étape par étape dans l'historique capturé.

---

## 📋 Documentation des Options (Directives 3.2.2)

| Option | Rôle métier dans Blackbox | Directive ENSET |
| :--- | :--- | :--- |
| `-h` | **Help** : Documentation détaillée et codes d'erreur. | 3.2.2 & 3.2.3 |
| `-w` | **Watch** : Surveillance continue et snapshots CPU/RAM à chaque commande. | Mode Principal |
| `-a` | **Analyze** : Analyse forensique (IPs, erreurs 4xx/5xx) et rapport d'audit. | Mode Principal |
| `-p` | **Playback** : Rejeu pas à pas d'une session enregistrée. | Mode Principal |
| `-s` | **Subshell** : Exécute la tâche dans un sous-shell isolé. | 3.2.2 & 3.2.4 |
| `-f` | **Fork** : Découpe les logs et lance des processus fils parallèles (`&`). | 3.2.2 & 3.2.4 |
| `-t` | **Thread** : Utilise `compress_helper` (C / Pthreads) pour la compression. | 3.2.2 & 3.2.4 |
| `-l` | **Log Dir** : Spécifie un répertoire personnalisé pour les logs. | 3.2.2 |
| `-r` | **Restore** : Réinitialise l'environnement (Admin uniquement). | 3.2.2 |

---

## ⚠️ Gestion des Erreurs et Auto-Help (Directive 3.2.3)

Blackbox gère activement les erreurs d'utilisation pour garantir la fiabilité. Chaque erreur affiche automatiquement l'aide complète.

| Code | Signification | Déclencheur |
| :--- | :--- | :--- |
| **100** | Option inconnue | `./blackbox --z` |
| **101** | Paramètre obligatoire manquant | `./blackbox -a` (sans nom de service) |
| **102** | Dossier de logs introuvable | `./blackbox -a inconnu` |
| **103** | Privilèges Root requis | `./blackbox -r` sans sudo |
| **104** | Fichier history.log manquant | `./blackbox -p 2025-01-01` |

---

## 📊 Journalisation Professionnelle (Directive 3.2.2)
Le fichier `history.log` (par défaut dans `/var/log/blackbox/`) respecte le format standard :
`AAAA-MM-JJ-HH-MM-SS : USERNAME : TYPE : MESSAGE`

**Types de messages (Audit Trail) :**
*   `INFOS` / `ERROR` : Messages de fonctionnement du script.
*   `CMD` / `RET` : Commandes interceptées et leurs codes de retour.
*   `SNAP` : Instantanés système (Charge CPU, RAM libre, Disque, Top 5 Processus).
*   `CORR` : Corrélation automatique entre une action humaine et une erreur de log.
*   `DANGER` : Alerte critique sur pattern dangereux (ex: `rm -rf /`).

---

## 📂 Architecture des Livrables (Directive 5)
```text
TeamID-devoir-shell/
├── blackbox                 # Script Bash principal (Exécutable)
├── Makefile                 # Automatisation de la compilation/installation
├── src/
│   ├── utils.sh             # Fonctions de journalisation et helpers
│   ├── mode_watch.sh        # Module de surveillance (Mode -w)
│   ├── mode_analyze.sh      # Module forensique (Mode -a)
│   └── compress_helper.c    # Code C multithreadé (Option -t)
├── bin/
│   └── compress_helper      # Exécutable binaire compilé
├── tests/
│   ├── generate_test_logs.sh # Générateur de données pour la démo
│   └── test_environment.sh   # Initialisation de l'env de test
├── docs/
│   ├── TeamID-devoir-shell.pdf   # Rapport détaillé (Captures & Specs)
│   └── TeamID-devoir-shell.pptx  # Présentation 180 secondes
└── README.md                # Cette documentation
```

---
**Projet Académique — ENSET Mohammedia 2026**  
*Auteur : Équipe Blackbox*
