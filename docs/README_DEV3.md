# Documentation Dev3 - Playback et Compression

Cette documentation explique seulement les deux fichiers de Dev3 :

```text
src/mode_playback.sh
src/compress_helper.c
```

## 1. `src/mode_playback.sh`

### Role

Ce fichier implemente le mode Playback :

```bash
./blackbox -p <date> <service>
```

Il relit `history.log` et rejoue les evenements a partir d'une date donnee.
Il affiche les commandes, les codes retour, les snapshots systeme, les
correlations et les alertes dangereuses.

Exemple :

```bash
./blackbox -l ./var/log/blackbox -p 2026-04-24_02-17-43 nginx
```

### Logique generale

```text
1. Recevoir la date donnee par l'utilisateur.
2. Convertir la date au format YYYY-MM-DD-HH-MM-SS.
3. Lire history.log ligne par ligne.
4. Ignorer les lignes plus anciennes.
5. Garder les lignes qui doivent etre rejouees.
6. Afficher les evenements par etapes.
7. Attendre Entree entre les etapes en mode interactif.
```

### Fonctions

| Fonction | Logique |
| --- | --- |
| `_playback_normalize_timestamp()` | Convertit la date utilisateur vers le format interne des logs. |
| `_playback_parse_line()` | Decoupe une ligne en timestamp, user, type et message. |
| `_playback_print_event()` | Affiche un evenement avec un label et une couleur. |
| `_playback_is_internal_event()` | Ignore les logs internes du playback pour eviter de les rejouer. |
| `_playback_pause()` | Attend que l'utilisateur appuie sur Entree. |
| `_playback_print_record()` | Choisit l'affichage selon le type : CMD, RET, SNAP, CORR, DANGER. |
| `playback_main()` | Fonction principale : filtre les logs puis les rejoue etape par etape. |

### Types de logs affiches

```text
CMD     commande executee
RET     code retour de la commande
SNAP    etat du systeme
CORR    correlation avec une erreur
DANGER  commande dangereuse
ERROR   erreur du script
INFOS   information
WARN    avertissement
```

### Commandes / syntaxes Bash utilisees

| Element | Pourquoi |
| --- | --- |
| `while IFS= read -r line` | Lire `history.log` proprement ligne par ligne. |
| `[[ "$PB_TS" < "$target_ts" ]]` | Comparer les dates car le format est triable alphabetiquement. |
| `case "$PB_TYPE" in ...` | Choisir quoi afficher selon le type de log. |
| `local -a playback_lines` | Stocker les lignes a rejouer dans un tableau. |
| `printf` | Affichage propre et plus fiable que `echo`. |
| `read -r _` | Attendre Entree pendant le playback. |

## 2. `src/compress_helper.c`

### Role

Ce fichier est un programme C utilise pour l'option `-t`.
Il compresse un rapport avec plusieurs threads.

Exemple :

```bash
./bin/compress_helper -j 4 archive.tar.gz rapport.txt
```

Signification :

```text
-j 4             utiliser 4 threads
archive.tar.gz   archive de sortie
rapport.txt      fichier source a compresser
```

### Logique generale

```text
1. Lire les arguments.
2. Verifier que le fichier source existe.
3. Creer un dossier temporaire dans /tmp.
4. Creer un fichier .tar temporaire.
5. Decouper le .tar en morceaux.
6. Lancer plusieurs threads.
7. Chaque thread compresse un morceau avec gzip.
8. Attendre la fin des threads.
9. Assembler les morceaux dans une archive .tar.gz.
10. Nettoyer les fichiers temporaires.
```

### Bibliotheques utilisees

| Bibliotheque | Pourquoi |
| --- | --- |
| `<pthread.h>` | Creer et attendre les threads avec `pthread_create()` et `pthread_join()`. |
| `<stdio.h>` | Lire/ecrire les fichiers avec `fopen()`, `fread()`, `fwrite()`. |
| `<stdlib.h>` | Gerer la memoire, les arguments et lancer `system()`. |
| `<string.h>` | Manipuler les chaines et les chemins. |
| `<sys/stat.h>` | Verifier que le fichier source existe avec `stat()`. |
| `<sys/types.h>` | Utiliser `off_t` pour les positions dans les fichiers. |
| `<unistd.h>` | Utiliser `getpid()`, `unlink()` et `rmdir()`. |
| `<limits.h>` | Utiliser `PATH_MAX` pour limiter la taille des chemins. |
| `<errno.h>` | Afficher des erreurs systeme plus claires. |

### Fonctions

| Fonction | Logique |
| --- | --- |
| `shell_quote()` | Protege les chemins pour les commandes shell. |
| `run_command()` | Execute une commande systeme avec `system()`. |
| `split_path()` | Separe un chemin en dossier et nom de fichier. |
| `create_tar()` | Cree un `.tar` temporaire avec `tar -cf`. |
| `copy_bytes()` | Copie des octets entre deux fichiers. |
| `create_chunk()` | Cree un morceau du fichier `.tar`. |
| `compress_chunk()` | Fonction executee par chaque thread, lance `gzip -c`. |
| `append_file()` | Ajoute un morceau compresse dans l'archive finale. |
| `cleanup_temp()` | Supprime les fichiers temporaires. |
| `write_parallel_gzip()` | Gere le decoupage, les threads et l'assemblage final. |
| `main()` | Lit les arguments, lance la compression et retourne le resultat. |

### Commandes systeme utilisees par le C

| Commande | Pourquoi |
| --- | --- |
| `tar -cf` | Creer une archive tar temporaire. |
| `gzip -c` | Compresser chaque morceau sans supprimer le fichier source. |

## 3. Resume

```text
mode_playback.sh  -> rejoue history.log pas a pas
compress_helper.c -> compresse un rapport avec pthread
```

Dev3 ajoute donc :

```text
1. Le rejeu des evenements apres un incident.
2. La compression multithread des rapports.
```

