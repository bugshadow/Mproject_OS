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

---

## 🛡️ Architecture de Sécurité & Permissions

Pour respecter le cahier des charges tout en permettant une surveillance multi-utilisateurs réelle, Blackbox utilise un modèle de permissions **"Audit-Ready"** :

### 1. Incorruptibilité du Log (history.log)
*   **Emplacement** : `/var/log/blackbox/history.log` (Conforme à la consigne du prof).
*   **Propriétaire** : **Root**.
*   **Droits (666)** : Le fichier est en lecture/écriture pour tous.
    *   *Pourquoi ?* Pour que chaque utilisateur surveillé (même sans droits sudo) puisse inscrire ses commandes dans le registre commun.
    *   *Sécurité* : Seul Root peut supprimer le dossier parent ou réinitialiser le système (`-r`).

### 2. Accessibilité des Scripts (755)
*   Tous les fichiers du projet (`src/`, `blackbox`) sont configurés en **755** via le `Makefile`.
    *   *Pourquoi ?* Pour que n'importe quel utilisateur (`testuser`, `hacker`) puisse charger les fonctions de surveillance lors de sa connexion, sans erreur de permission.

---

## 🛠️ Installation et Préparation

```bash
# 1. Récupérer le projet
git clone -b omar https://github.com/bugshadow/Mproject_OS.git
cd Mproject_OS

# 2. Configurer les permissions AUTOMATIQUEMENT (Directives 3.2.2 & Makefile)
make

# 3. Générer les logs de test (Indispensable pour la démonstration)
./tests/generate_test_logs.sh
```

---

## 🧪 Guide de Démonstration "Zéro Échec"

### Scénario A : Surveillance Multi-Utilisateurs (La Preuve de Concept)
*Objectif : Prouver que vous pouvez espionner n'importe quel utilisateur en temps réel.*

1.  **Terminal 1 (Admin)** : Lancez la surveillance globale.
    ```bash
    sudo ./blackbox -w sshd
    ```
2.  **Terminal 2 (Le "Hacker")** : Simulez une intrusion.
    ```bash
    # Créer un utilisateur test (s'il n'existe pas)
    sudo useradd -m testuser && sudo usermod -s /bin/bash testuser
    
    # Se connecter (Le message "SURVEILLANCE ACTIVÉE" doit apparaître !)
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
    *Vous verrez apparaître `testuser`, ses commandes, et le flag rouge **DANGER**.*

### Scénario B : Traitement Moyen (Fork `-f` + Analyze `-a`)
*Objectif : Prouver l'utilisation de processus fils pour l'analyse de logs lourds.*
```bash
sudo ./blackbox -f -a nginx
```
*Vérification : Dans un autre terminal, tapez `ps faux | grep blackbox` pour voir les processus parallèles.*

### Scénario C : Traitement Lourd (Thread `-t` + Playback `-p`)
*Objectif : Valider l'utilisation de threads Pthreads (C) pour la compression.*
```bash
# Analyse avec compression multithreadée
sudo ./blackbox -t -a nginx

# Rejeu de la session (le "Film" du crash)
sudo ./blackbox -p 2026-05-01
```

---

## ⚠️ Rappel des Codes d'Erreurs (Directive 3.2.3)

| Code | Signification | Déclencheur |
| :--- | :--- | :--- |
| **100** | Option inconnue | `./blackbox --z` |
| **101** | Paramètre obligatoire manquant | `./blackbox -a` (sans service) |
| **102** | Dossier de logs introuvable | `./blackbox -a inconnu` |
| **103** | Privilèges Root requis | `./blackbox -r` sans sudo |
| **104** | Fichier history.log manquant | `./blackbox -p 2025-01-01` |

---
**Projet Académique — ENSET Mohammedia 2026**
