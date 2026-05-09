# Documentation Tests - Validation et Démos

Cette documentation explique la partie des scripts de tests du projet :

```text
tests/demonstration_prof.sh
tests/generate_test_logs.sh
tests/test_environment.sh
tests/test_telegram_alert.sh
tests/test_twilio_sms.sh
tests/test_watch.sh
```

## 1. Scripts de generation et validation environnementale

### `tests/generate_test_logs.sh`
**Role** : Creer un environnement simule pre-existant qui permet de tester efficacement le mode Analyze (Dev 2).
**Logique generale** : Il remplit le dossier `/var/log` (ou log local) avec des journaux applicatifs falsifiés, injectant aleatoirement des erreurs intelligentes et traces IPs que le systéme Forensique Dev2 pourra analyser positivement.

### `tests/test_environment.sh`
**Role** : Valider de manière automatique que tous les pre-requis de l'OS Linux et droits sont au vert pour accueillir Blackbox.
**Logique generale** : Scanne l'existence command-line de `bc`, `tar`, `pthread`, `curl`, `awk` et les variables globales de developpement.

## 2. Démos Interactives & API

### `tests/demonstration_prof.sh`
**Role** : Servir de scenario standard executable pour appuyer visuellement la demarche fonctionnelle globale du projet pendant les soutenances. Executer pas à pas les etapes maitresses.

### `tests/test_telegram_alert.sh` et `tests/test_twilio_sms.sh`
**Role** : Scripts d'injection et de validation de connection pour l'API Bot Telegram ou l'API Twilio (SMS).
**Logique generale** : Ces fichiers emportent la logique indépendante de charger des identifiants et des variables `.env` et déclenchent une requete `cURL` (POST HTTP) basique pour s'assurer que la stack API répond correctement sans erreur réseau.

## 3. Scenarios Comportementaux (Mode Watch)

### `tests/test_watch.sh`
**Role** : Verifier l'intégrité de l'interception anti-fraude shell.
**Logique generale** : 
1. Il orchestre de faire demarrer la sandbox Dev 1 Blackbox Watch en isolation ou daemon.
2. Il simule de fausse écritures (echo), frappe (history) dangeureuses (chmod 777).
3. Lit le retour et statut code bash depuis le log file pour acter ou non la reussite parfaite de detection intrus.
