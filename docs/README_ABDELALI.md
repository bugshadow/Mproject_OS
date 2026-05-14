# Documentation Dev2 - Analysis & Forensics

Cette documentation explique les fichiers de Dev2 (Analysis & Forensics) :

```text
src/mode_analyze.sh
```

## 1. `src/mode_analyze.sh`

### Role
Ce fichier implemente le mode Analyze (Option `-a`). Il effectue l'audit post-incidents d'un service spécifique en examinant ses fichiers journaux `.log`, il repere de facon croisée les erreurs générées suite aux actions directes enregistrées par un utilisateur, et compacte une archive de rapport exhaustive finale.

### Logique generale
```text
1. Résoudre intelligemment le chemin contenant les logs d'un service via des tests d'existences.
2. Phase 1 : Evaluer les capacités brutes et présentes du système (Profilage matériel CPU/MEM).
3. Phase 2 : Compiler le renseignement d'Erreur. Parser dynamiquement via processus unique, ou via Forking (Multi-processus) la fréquence des codes statuts d'erreur et Top IPs requêtrices.
4. Phase 3 : Assurer la Corrélation. Identifier la temporalité d'interception d'une Commande depuis history.log avec le rapprochement immédiat d'une erreur avérée sur système.
5. Phase 4 : Generer, fusionner toutes les variables de temp, exporter en fichier consolidé de Synthèse pour archivage et le laisser compresser.
```

### Fonctions

| Fonction | Logique |
| --- | --- |
| `analyze_main()` | Routeur et Controlleur central des contextes d'Analyse. Séquence le flux pas-à-pas. |
| `_resolve_log_path()` | Analyse heuristiquement sur divers dossiers (`/var/log`, locaux, tests) la probabilité de logs du service donné. |
| `_phase_system_profiling()` | Écrit une snapshot textuel locale du système (utilisant awk, bc, free, pc). |
| `_phase_log_forensics()` | Mode Séquentiel Simple : Appelle la boucle classique de lecture sur tout `*.log` trouvé. |
| `_phase_log_forensics_fork()` | Mode de Traitement Accéléré (`FLAG_FORK`) utilisant la commande `split` en 4 blocs, invoquant simultanement via `&` sur shell et rattachant via la primitive `wait` PIDs. |
| `_analyze_single_file()` | Exécute des primitives `grep/sort/uniq` visant à indexer le TOP 10 IPs et compter les erreurs (404, 500, 403, 502). |
| `_analyze_chunk()` | Mini-routines exécutées aveuglément pour parser un unique bout de fichier pendant le Parallel Forking. |
| `_merge_fork_results()` | Fait converger l'ensemble des outputs partagés `/tmp` du Fork vers une trace incrémentale propre globale. |
| `_phase_correlation()` | **L'Ame de Blackbox Forensics.** Croise l'empreinte logicielle (`history.log`) sur l'empreinte journalisée et averti formellement du rapprochement `CMD → +T.secondes → ERROR`. |
| `_ts_to_epoch()` | Opère le parsing de la date textuelle du log (ex:`2026-04-21-02-17-43`) en Secondes POSIX (Unix Epoch). |
| `_find_errors_near_timestamp()` | Cherche itérativement un seuil de proximité limitrophe temporel configuré (`DANGER_THRESHOLD`) pour certifier la relation de cause à effet. |
| `_phase_generate_report()` | Assemble textuellement dans un `.md` de sortie tous logs isolés, transfère vers `archives/` suivi d'une tentative de compactage multithread ou classique vers du `.tar.gz`. |
