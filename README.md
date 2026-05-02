# Blackbox - La Boîte Noire pour Serveurs Linux

> "Parce que chaque crash mérite une enquête."
> Un outil Bash robuste pour l'enregistrement, la corrélation et le rejeu d'incidents système.

---

## 1. Contexte et Objectif

### Le Scénario Réel
Il est 02h17 du matin. Le serveur de production s'arrête. 50 000 utilisateurs sont bloqués. L'administrateur système se connecte et fait face à un système complexe à déboguer :
- Des milliers de lignes de logs éparpillées sans contexte.
- Un historique (history) sans horodatage précis, facilement effaçable par un attaquant.
- Aucun moyen de savoir quel utilisateur a exécuté quelle commande au moment exact où la RAM a saturé.

**La Solution : Blackbox** 
Blackbox agit comme l'enregistreur de vol d'un avion : il capture les actions humaines, l'état de la machine (Snapshots) et les erreurs système (Corrélation). Il permet ensuite de rejouer la séquence d'événements (Playback) pour identifier la cause fondamentale de manière ciblée et rapide.

---

## 2. Architecture de Sécurité et Permissions

Afin de respecter le cahier des charges et de permettre une véritable surveillance multi-utilisateurs sécurisée, Blackbox repose sur une architecture stricte :

- **Incorruptibilité du Log (history.log)** :
  - **Emplacement par défaut** : `/var/log/blackbox/history.log`
  - **Propriétaire** : Administrateur (Root).
  - **Droits (666)** : Lecture et écriture pour tous. Cela permet à tout utilisateur surveillé d'inscrire ses commandes dans le registre commun. Seul l'administrateur (Root) peut supprimer le dossier parent ou utiliser l'option de réinitialisation (`-r`).

- **Accessibilité des Scripts** :
  - L'ensemble du projet (`src/`, `blackbox`) est configuré avec les droits d'exécution `755` via le `Makefile`. Tout utilisateur peut charger le hook de surveillance, mais ne peut pas altérer la logique du script.

---

## 3. Installation et Préparation (Environnement VMware / Test)

```bash
# 1. Cloner le référentiel
git clone -b omar https://github.com/bugshadow/Mproject_OS.git
cd Mproject_OS

# 2. Configurer les permissions et compiler l'utilitaire C (Multithreading)
make

# 3. Générer les logs de test (Requis pour l'analyse)
./tests/generate_test_logs.sh
```

---

## 4. Modes Principaux et Variantes de Commandes

Blackbox s'exécute selon la syntaxe suivante : `blackbox [OPTIONS] <SERVICE_NAME>`

### Option Obligatoire (Comportement) :
- `-w` (Watch)   : Active la surveillance continue (interception des commandes terminal + snapshot).
- `-a` (Analyze) : Lance l'analyse forensique des fichiers de logs du service spécifié.
- `-p <DATE>`    : Active le mode Playback pour rejouer l'historique d'une date (Format: YYYY-MM-DD).

### Options Modificatrices (Traitement) :
- `-s, --subshell` : Isole l'exécution du daemon de surveillance dans un sous-shell.
- `-f, --fork`     : Active le découpage des gros fichiers logs et l'analyse via processus parallèles.
- `-t, --thread`   : Utilise le module développé en C (Pthreads) pour la compression asynchrone.
- `-l <REP>`       : Définit un répertoire personnalisé pour les journaux (`-l ./var/log`).
- `-v, --verbose`  : Affiche les détails des opérations en temps réel.
- `-r, --restore`  : Supprime et rénitialise tous les logs (Nécessite les privilèges `sudo`).
- `-h, --help`     : Affiche la documentation technique intégrée.

---

## 5. Guide Complet d'Utilisation (Cas d'Usages)

Cette section détaille les commandes à exécuter pour tester chaque fonctionnalité isolément ou en combinaison. Elle est conçue pour permettre à l'ensemble de l'équipe de valider le programme sur machine virtuelle.

### 5.1. Consultation de la Documentation (-h)
**Objectif** : Afficher les instructions et le manuel complet.
**Commande** :
```bash
./blackbox -h
```
**Exemple de sortie attendue** : Le terminal affiche la grande bannière ASCII suivie du manuel détaillé (SYNOPSIS, DESCRIPTION, EXEMPLES, CODES D'ERREURS).

### 5.2. Surveillance Continue Standard (Watch Mode)
**Objectif** : Intercepter les commandes utilisateur en temps réel et valider la détection de mots clés.
**Commande** :
```bash
./blackbox -l ./var/log -v -w syslog
```
**Explication** : Active le mode Watch (`-w`). L'option Verbose (`-v`) affiche chaque frappe clavier en direct.

### 5.3. Démonstration Interactive : Capture Multi-Utilisateurs (Preuve de Concept)
**Objectif** : Prouver que Blackbox enregistre secrètement les actions dangereuses d'un autre utilisateur système.
**Procédure à suivre sur la machine virtuelle** :

1. **Terminal 1 (Administrateur)** : Lancez la surveillance globale.
   ```bash
   sudo ./blackbox -w sshd
   ```
2. **Terminal 2 (Le "Hacker" / Testeur)** : Simulez une connexion et comportez-vous de façon suspecte.
   ```bash
   # Création rapide d'un utilisateur de test
   sudo useradd -m testuser && sudo usermod -s /bin/bash testuser
   
   # Connexion (Le hook Blackbox s'active en arrière-plan)
   sudo su - testuser
   
   # Taper des commandes irrégulières ou dangereuses
   ls -la /root
   chmod 777 /etc
   exit
   ```
3. **Terminal 1 (Administrateur)** : Vérifiez la capture infaillible dans le registre.
   ```bash
   sudo cat /var/log/blackbox/history.log
   ```
   **Résultat attendu** : Vous verrez apparaître le nom `testuser`, la commande interdite `chmod 777 /etc`, suivie immédiatement de l'alerte **DANGER** insérée automatiquement par Blackbox.

### 5.4. Analyse Forensique Standard (Analyze Mode)
**Objectif** : Générer un rapport d'incidents (IPs, erreurs HTTP) sans parallélisation.
**Commande** :
```bash
./blackbox -l ./var/log -a nginx
```
**Explication** : Analyse séquentiellement les logs du service cible.
**Exemple de sortie attendue** :
```text
▶ Fichier: nginx_access_small.log
Top IPs connectees:
  12288x  →  192.168.1.10
Erreurs HTTP:
  404 (Not Found)       : 4096
✓ Rapport genere: ./var/log/archives/..._report.tar.gz
```

### 5.5. Scénarios Avancés (Exigences de Soutenance)

**Scénario A : Traitement Léger (Isolation Subshell + Watch)**
**Commande** :
```bash
./blackbox -s -l ./var/log -v -w cron
```
**Explication** : Le flag `-s` exécute la surveillance dans un PID totalement dissocié du parent `bash`, sécurisant ainsi l'environnement.

**Scénario B : Traitement Moyen (Multiprocessing Fork + Analyze)**
**Commande** :
```bash
./blackbox -f -l ./var/log -a nginx
```
**Explication** : Active le mécanisme de Fork (`-f`). Les fichiers volumineux sont découpés en 4 segments (`chunk`) et dispatchés via `&`. Les PIDs concurrents sont affichés et gérés par des commandes `wait`.

**Scénario C : Traitement Lourd (Compression Multithread C + Playback)**
**Commande** :
```bash
./blackbox -t -l ./var/log -p "2026-04-21" apache2
```
**Explication** : La compilation C (`compress_helper`) exploitant la bibliothèque POSIX Threads (Pthreads) gère une compression parallèle extrêmement rapide, suivie du rejeu visuel pas-à-pas de l'incident.

---

## 6. Test de Résilience et Validation des Codes d'Erreurs

Afin de démontrer la rigueur de la gestion d'erreurs (Directive 3.2.3), voici les commandes pour tester chaque code de sortie. Toute erreur interrompt le processus et affiche la documentation simplifiée de l'outil.

### Code 100 : Option inexistante ou Syntaxe invalide
**Commande** : 
```bash
./blackbox --unknown
```
**Comportement attendu** : Affiche `ERREUR 100 : Option inconnue`. Validation du rejet d'arguments non spécifiés dans la boucle `getopts`.

### Code 101 : Paramètre obligatoire manquant
**Commande** : 
```bash
./blackbox -a
```
**Comportement attendu** : Affiche `ERREUR 101 : Paramètre obligatoire manquant`. L'utilisateur a oublié d'indiquer le `SERVICE_NAME` (ex: apache, nginx) à la fin de la commande.

### Code 102 : Dossier de journaux source (Log) introuvable
**Commande** : 
```bash
./blackbox -l ./var/log -a service_inexistant
```
**Comportement attendu** : Affiche `ERREUR 102 : Repertoire source introuvable`. Le script d'analyse n'a trouvé aucun répertoire lié au nom "service_inexistant" dans `/var/log` ou en local.

### Code 103 : Privilèges Administrateur requis (Restore)
**Commande** : 
```bash
./blackbox -r
```
**Comportement attendu** : Affiche `ERREUR 103 : Tentative d'action critique sans droits administrateur`. L'option `-r` supprime les archives, ce qui est formellement bloqué (vérification `id -u` interne) pour tout utilisateur sans le préfixe `sudo`.

### Code 104 : Fichier "history.log" introuvable pour rejeu (Playback)
**Commande** : 
```bash
./blackbox -l ./dossier_vide -p "2026-05-01" nginx
```
**Comportement attendu** : Affiche `ERREUR 104 : Fichier history.log introuvable`. Le rejeu historique ne peut pas s'effectuer sur un répertoire vierge de toute activité antérieure.

---

## 7. Concepts Fondamentaux des Systèmes d'Exploitation (SE)

Afin de lier cet outil à la réalité fondamentale des Systèmes d'Exploitation (SE) et de l'administration Unix/Linux, Blackbox a été conçu pour mettre en œuvre les concepts théoriques suivants :

*   **Gestion des Processus (Forking & Subshells)** :
    *   Le paramètre `-f` illustre la création de processus lourds concurrents. Le système alloue un PID et un espace mémoire distincts pour chaque bloc de lecture (`chunk`), démontrant la puissance du multiprocessing.
    *   Le paramètre `-s` démontre l'isolation d'environnements (les variables et statuts du sous-shell n'affectent pas le shell parent).
*   **Multithreading concurrentiel (POSIX Threads C)** :
    *   Le paramètre `-t` fait appel à une routine C bas-niveau. Plutôt que de cloner tout l'espace mémoire (Fork), il crée des processus "légers" (Threads) partageant le même espace mémoire pour paralléliser la compression GZIP.
*   **Synchronisation et Verrous (IPC / Mutex)** :
    *   Dans un environnement multi-utilisateurs, plusieurs administrateurs peuvent taper des commandes simultanément. Pour éviter la corruption du fichier journal (`history.log`) via de potentiels *Race Conditions* (accès concurrent), Blackbox exploite `flock` (File Lock), illustrant les mécanismes d'exclusion mutuelle.
*   **Signaux Inter-Processus (SIGINT / SIGTERM)** :
    *   L'utilisation de `trap` (ex: `trap 'cleanup' INT TERM EXIT`) montre la capacité du script à intercepter des signaux envoyés par le noyau (ex: `Ctrl+C`) pour déclencher un nettoyage garantissant aucune fuite de mémoire ou processus Zombie.
*   **Contrôle d'Accès & Sécurité (Permissions UNIX)** :
    *   L'outil s'appuie sur la vérification des UIDs (User ID) pour restreindre l'option Restore au Root (`id -u == 0`) et montre l'usage des droits Discrétionnaires (666 pour l'écriture conjointe, 755 pour l'exécutable `compress_helper`).

---

## 8. Cas d'Usage Métier (Scénarios Pratiques de Test)

Pour éprouver concrètement l'outil face à des situations réelles d'administration système et de cybersécurité, voici trois scénarios métiers que vous pouvez tester :

### Cas 1 : Investigation d'une attaque par Force Brute (Mode Analyze)
**Contexte** : Le serveur Web est saturé par des milliers de requêtes entrantes. L'administrateur doit identifier instantanément les IPs malveillantes.
**Test à exécuter** :
```bash
# Générer un faux trafic intensif (si tests/generate_test_logs.sh ne l'a pas déjà fait)
./blackbox -f -t -l ./var/log -a nginx
```
**Observation** : Blackbox utilise le Forking (`-f`) et le Multithreading (`-t`) pour analyser massivement les logs `nginx`, révélant en un temps record les adresses IP ayant causé des erreurs 403/404 successives, typiques d'un scanneur de vulnérabilités.

### Cas 2 : Détection d'Intrusion et d'Escalade de Privilèges (Mode Watch)
**Contexte** : Un attaquant a potentiellement compromis un compte utilisateur standard. Il tente de changer les mots de passe root ou d'effacer les traces. L'admin active une surveillance discrète.
**Test à exécuter** :
```bash
./blackbox -s -l ./var/log -w auth
# Dans un autre terminal :
su - testuser
cat /etc/shadow
```
**Observation** : Le mode Watch tourne en isolation via Subshell (`-s`). L'action de lecture de `/etc/shadow` est immédiatement identifiée comme une anomalie, horodatée et remontée à l'administrateur sans interrompre les autres processus du serveur.

### Cas 3 : Post-Mortem d'un Incident (Mode Playback)
**Contexte** : Un service est tombé hier. L'équipe d'astreinte doit revoir la chronologie des commandes tapées par le technicien précédent pour comprendre pourquoi le service a planté.
**Test à exécuter** :
```bash
./blackbox -l ./var/log -p "2026-05-02" cron
```
**Observation** : Le rejeu pas-à-pas (Playback) donne l'illusion de regarder un enregistrement vidéo de la session du technicien, permettant de détecter exactement à quelle seconde une commande destructive a été initiée.

---

## 9. Fonctionnalité Bonus : Intégration Telegram (Real-Time SOC)

Pour rapprocher ce projet des standards professionnels des Security Operations Centers (SOC), Blackbox intègre une API de notification en temps réel.
Dès qu'une commande dangereuse (ex : `chmod 777`) est tapée sur un terminal compromis, Blackbox envoie de manière **asynchrone** (via un `Subshell &` et `curl`) une alerte formatée vers l'application Telegram de l'administrateur système.

### Configuration du Bot :
1. Fichier : Créez (ou modifiez) un fichier `.env` à la racine du projet.
2. Contenu requis :
   ```env
   TELEGRAM_BOT_TOKEN="votre_token_du_botfather"
   TELEGRAM_CHAT_ID="votre_id_telegram"
   ```
3. Test immédiat : `bash tests/test_telegram_alert.sh`

*(Note: Le .env est ignoré dynamiquement via le `.gitignore` pour prévenir toute fuite de clés API).*

---
**Module : Théorie des systèmes d'exploitation & SE Windows/Unix/Linux**
*École Normale Supérieure de l'Enseignement Technique de Mohammedia (ENSET) — 2026*

---
**Module : Théorie des systèmes d'exploitation & SE Windows/Unix/Linux**
*École Normale Supérieure de l'Enseignement Technique de Mohammedia (ENSET) — 2026*
