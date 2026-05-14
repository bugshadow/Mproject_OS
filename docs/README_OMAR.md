# Documentation Dev1 - Core Architecture et Mode Watch

Cette documentation explique les fichiers de Dev1 (Core Architecture & Module Watch) :

```text
blackbox
src/utils.sh
src/mode_watch.sh
```

## 1. `blackbox`

### Role
Ce fichier est le point d'entree principal de l'application Blackbox. Il orchestre les redirections vers les differents modules, gere les parametres passes par l'utilisateur et initialise l'environnement des logs.

### Logique generale
```text
1. Mettre en place les couleurs ANSI et les variables globales modifiables de Blackbox.
2. Invoquer le parser d'options `getopts`.
3. Initialiser physiquement les espaces de travail par `init_environment` (touch fichier et chmod log).
4. Verifier et valider les presences du Service à Monitorer.
5. Invoquer de le lancement respectif du Dispatcher selon `MODE` defini.
```

### Fonctions

| Fonction | Logique |
| --- | --- |
| `die()` | Fonction centrale pour stopper le script en cas d'erreur. Elle écrit la cause et renvoie une fenêtre d'erreur descriptive. |
| `parse_options()` | Utilise la boucle `getopts` pour decrypter `(-h, -w, -a, -p, -s, -f, -t, -v, -A, -l, -r)`. |
| `init_environment()` | Structure logiciellement les configurations repertoires `history.log` selon un schema multi-utilisateur incorruptible `666`. |
| `validate()` | Exécute des vérifications ciblées de sécurité ou de présence de répertoire cible en rapport au mode invoqué. |
| `mode_restore()` | Fonction de nettoyage critique (nécessite super-utilisateur). Détruit les traces globales `log`. |
| `run_mode()` | Dispatche (case logic) l'appel vers `watch_main()`, `analyze_main()`, `playback_main()`, etc. |
| `main()` | Point superieur d'execution, encapsulant le contrôle du paramètre isolation de sous-shell (`FLAG_SUBSHELL`). |

## 2. `src/utils.sh`

### Role
Ce module regroupe de manière mutualisée le support de sortie (journalisation via `log_event()`), design et de nettoyage de signaux.

### Logique generale
```text
1. Mettre en place un piege (trap) global de fin de signaux pour interrompre élégament.
2. Definir le moteur `log_event()` multithread safe.
3. Afficher structurellement la documentation formattee ASCII.
```

### Fonctions

| Fonction | Logique |
| --- | --- |
| `cleanup()` | Se positionne sur `trap` avec les signaux `INT TERM EXIT` pour purger ou aviser. |
| `log_event()` | Fonction asynchrone majeure exploitant le `flock 200` Unix. Inclus timestamps, gestion utilisateur et l'esthétique Bash Couleur pour modes `[CMD, SNAP, CORR, DANGER]`. |
| `print_banner()` | Affichage standard du composant ASCII d'entête Dev 1. |
| `display_help()` | Description textuelle et syntaxique presentee aux clients via commande `-h`. |
| `display_error_help()` | Variante allegée condensée de l'erreur afin de ne pas envahir l'interface visuelle inutilement. |

## 3. `src/mode_watch.sh`

### Role
C'est le module de capture (Intrusion Detection System / IDS). Il s'implante via les hooks internes Bash afin d'enregistrer discrètement l'historique shell en direct (CMD, REtours) avec une capture contextuelle Snapshot. Des alertes Telegram s'y relient.

### Logique generale
```text
1. Enregistrer selon la cible (-w) le profil general.
2. Installer silencieusement les variables et un module profil shell si l'utilisateur est administrateur.
3. Modifier le trap environnement PROMPT pour lire les executions via commande standard d'historique interne et les transiter à logs.
4. Lancer une verification de pertinence de securite par expressions regulière (Patterns dangereux).
5. Soumettre pour alertes externes le script via hook telegram background si requis.
```

### Fonctions

| Fonction | Logique |
| --- | --- |
| `__blackbox_snapshot()` | Construit la memoire vive, disque, % CPU via awk/bash (`uptime, free, df, ps`) a fin d'imprimer la signature du materiel a l'instant `t`. |
| `__blackbox_correlate()` | Identifie immediatement de nouvelles lignes ou anomalies via soustraction naive de tailles fichiers entre avant et apres lexecution. |
| `__blackbox_danger_patterns()` | Dictionnaire statique integrant des expressions Regex red (ex: rm -rf, mkfs..). |
| `__send_telegram_alert()` | Integration de curl WebHook basee sur API BOT formattee au theme IDS Alerte Critique (background safe). |
| `__blackbox_danger_check()` | Verifie le Pattern Matching via listes iteratives. Active les Alertes telegram au premier matching fatal. |
| `__blackbox_watch_precmd()` | Hook preambule attache a DEBUG, pre-configurant l'anti-fraude historique. |
| `__blackbox_watch_postcmd()` | Hook `PROMPT_COMMAND`. Extract historique commande, l'anti-doublon et parse log_event pour Snap et Alertes successifs. |
| `__install_local_hook()` | Deploie dans la session pure courrante une attache piege dynamique. |
| `__install_system_hook()` | Construit et parse sous `/etc/profile.d/blackbox-watch.sh` pour surveiller multi-utilisateurs l'ensemble shell globaux. |
| `watch_main()` | Controlleur maitre; execute l'injection Profile vs Utilisateur et genere the Prompt contextuel terminal cible (-w). |
