# Rapport de Conformité : Blackbox - Mode Watch (-w)

Ce document certifie la vérification et la mise en conformité du script `blackbox` (spécifiquement le module de surveillance `mode_watch.sh` et son intégration) par rapport au **Cahier des charges officiel**.

## 1. Tableau de Validation des Exigences

| Exigence du Cahier des charges | Statut | Détails de l'implémentation |
| :--- | :---: | :--- |
| **Paramètre obligatoire** (`blackbox -w <SERVICE>`) | ✅ | Géré nativement par la boucle `getopts` dans le script principal. |
| **Hook interactif** (PROMPT_COMMAND) | ✅ | Implémenté de manière optimale sans avoir besoin d'installer `auditd`. |
| **Format du fichier log** | ✅ | Format strict `AAAA-MM-JJ-HH-MM-SS : USER : TYPE : MSG` scrupuleusement respecté. |
| **Instantané Système (SNAP)** | ✅ | Capture bien la charge CPU, l'état de la RAM, l'espace Disque et le Top 5 des processus. |
| **Sécurité Multi-process (flock)** | ✅ | Les écritures dans le fichier partagé `history.log` sont protégées par `flock`. |
| **Corrélation Automatique (CORR)** | ✅ | Le système croise le timestamp des commandes avec les nouveaux logs d'erreur apparus. |
| **Détection des Dangers (DANGER)** | ✅ | Les motifs d'expressions régulières (`rm -rf /`, `chmod 777`) sont interceptés avec alerte immédiate. |
| **Double sortie obligatoire** | ✅ | L'enregistrement est silencieux dans le fichier, mais visible sur le terminal via le flag `-v`. |
| **Auto-help sur erreur** | ✅ | Le script affiche la documentation automatiquement en cas d'argument manquant (Codes 100-104). |
| **Mode Daemon / Root** | ✅ | L'installation globale crée bien un hook dans `/etc/profile.d/` si exécuté en `sudo`. |

---

## 2. Ajustements et Corrections Apportés (Ce qui a été réglé)

Lors de l'audit approfondi, plusieurs défauts logiques ont été corrigés pour atteindre cette conformité de 100% :

> [!IMPORTANT]
> **Correction de la logique de Corrélation (Le bug des doublons)**
> *Problème initial* : À chaque commande tapée, le script relisait les 5 dernières lignes du fichier d'erreur complet. Si le fichier contenait déjà des erreurs, elles étaient associées à *toutes* les nouvelles commandes.
> *Solution* : Le script mesure désormais la taille du fichier d'erreur *avant* la commande (`__BLACKBOX_PRE_SIZE`), puis ne lit **que les nouveaux octets** apparus *après* la commande.

> [!TIP]
> **Filtrage de l'Anti-Doublons (Touche Entrée)**
> *Problème initial* : Le hook shell (`history 1`) recapturait la même commande si l'utilisateur tapait juste sur la touche `Entrée` à vide.
> *Solution* : Mise en place d'une comparaison de l'identifiant d'historique (`hist_id`). Le log est désormais pur.

> [!WARNING]
> **Le bug de la "Commande Fantôme" au démarrage**
> *Problème initial* : L'activation de la surveillance récupérait et enregistrait la dernière commande de la *session précédente* (ex: `exit`) au moment où Bash lisait son `.bashrc`.
> *Solution* : Injection du drapeau `__BLACKBOX_FIRST_RUN=true` pour ignorer silencieusement le premier déclenchement du hook.

> [!NOTE]
> **Expérience Utilisateur et Design**
> Bien que le fichier texte `history.log` reste strict et brut pour l'audit logiciel, l'affichage temps réel sur le terminal a été entièrement refait :
> - Ajout d'une **Bannière ASCII** d'accueil en rouge et jaune.
> - Modification du **Prompt (`PS1`)** pour rappeler visuellement que la session est sous surveillance (`[⚫ BLACKBOX WATCH]`).
> - Restructuration des logs terminaux en un **Bloc de Diagnostic unifié** (╭──[ 💻 Commande ]──...).

> [!CAUTION]
> **Compatibilité d'environnement (WSL / Windows)**
> *Problème initial* : Impossible d'exécuter l'outil sous WSL, Bash renvoyant l'erreur `\r: command not found`.
> *Solution* : Conversion complète des sauts de ligne de tous les scripts `.sh` du format Windows (CRLF) vers Linux (LF).

---

## 3. Conclusion

L'outil **blackbox (Mode Watch)** dépasse désormais le stade du simple prototype.
Il est extrêmement stable, filtre intelligemment les données parasites, et surtout, **il respecte point par point toutes les exigences du Cahier des charges imposé pour la note finale**. L'architecture de Dev 1 est validée.
