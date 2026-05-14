CC = gcc
CFLAGS = -Wall -Wextra -pthread
SRC_DIR = src
BIN_DIR = bin

# La règle par défaut DOIT être la première du fichier
all: init clean create_dirs build install env_setup success

# Ajout d'une règle "init" pour configurer les permissions
init:
	@echo "Configuration des permissions en cours..."
	@chmod +x blackbox tests/*.sh
	@chmod -R 755 .
	@echo "Permissions d'execution et de lecture (755) accordees avec succes !"

success:
	@printf "\n\033[1;32m[✓] Configuration et Installation terminees avec succes !\033[0m\n"
	@printf "\033[1;34m[Etape Suivante]\033[0m Vous pouvez maintenant taper directement : \033[1;33mblackbox -h\033[0m depuis n'importe quel dossier\n\n"

create_dirs:
	@echo "Creation des dossiers necessaires..."
	@mkdir -p $(BIN_DIR)

build:
	@echo "Verification et compilation du code C..."
	@if [ -f $(SRC_DIR)/compress_helper.c ]; then \
		$(CC) $(CFLAGS) $(SRC_DIR)/compress_helper.c -o $(BIN_DIR)/compress_helper; \
		echo "-> Compilation de $(SRC_DIR)/compress_helper.c terminee avec succes."; \
	else \
		echo "-> Info: $(SRC_DIR)/compress_helper.c non trouve. Etape ignoree (Normal, pour Dev 3)."; \
	fi

clean:
	@echo "Nettoyage des anciens fichiers binaires..."
	@rm -rf $(BIN_DIR)/*

install:
	@echo "Installation de blackbox dans /usr/local/bin (peut necessiter les droits administrateur/sudo)..."
	@ln -sf $(CURDIR)/blackbox /usr/local/bin/blackbox
	@printf "\033[1;32m[✓] Installation terminee ! Vous pouvez maintenant utiliser la commande 'blackbox' depuis n'importe quel dossier.\033[0m\n"

env_setup:
	@if [ ! -f .env ]; then \
		touch .env; \
		printf "\n\033[1;33m⚙️  Configuration de l'alerte Telegram (Optionnel)\033[0m\n"; \
		read -p "Entrez votre TELEGRAM_BOT_TOKEN (Entree pour ignorer) : " token; \
		read -p "Entrez votre TELEGRAM_CHAT_ID (Entree pour ignorer) : " chatid; \
		if [ -n "$$token" ] && [ -n "$$chatid" ]; then \
			echo "TELEGRAM_BOT_TOKEN=\"$$token\"" >> .env; \
			echo "TELEGRAM_CHAT_ID=\"$$chatid\"" >> .env; \
			printf "\033[1;32m[✓] Configuration Telegram ajoutee au fichier .env !\033[0m\n"; \
		else \
			printf "\033[1;30m[i] Configuration Telegram ignoree.\033[0m\n"; \
		fi; \
		printf "\n\033[1;33m📱 Configuration de l'alerte SMS Twilio (Optionnel)\033[0m\n"; \
		read -p "Voulez-vous configurer les alertes SMS ? (O/n) : " ans; \
		if [ "$$ans" = "O" ] || [ "$$ans" = "o" ] || [ "$$ans" = "y" ] || [ "$$ans" = "Y" ] || [ -z "$$ans" ]; then \
			read -p "   - TWILIO_ACCOUNT_SID : " tsid; \
			read -p "   - TWILIO_AUTH_TOKEN : " ttoken; \
			read -p "   - TWILIO_FROM_NUMBER (Expediteur ex: +1234..) : " tfrom; \
			read -p "   - TWILIO_TO_NUMBER (Destinataire ex: +1234..) : " tto; \
			echo "TWILIO_ACCOUNT_SID=\"$$tsid\"" >> .env; \
			echo "TWILIO_AUTH_TOKEN=\"$$ttoken\"" >> .env; \
			echo "TWILIO_FROM_NUMBER=\"$$tfrom\"" >> .env; \
			echo "TWILIO_TO_NUMBER=\"$$tto\"" >> .env; \
			printf "\033[1;32m[✓] Configuration SMS Twilio ajoutee au fichier .env !\033[0m\n"; \
		else \
			printf "\033[1;30m[i] Configuration SMS ignoree.\033[0m\n"; \
		fi; \
		printf "\033[1;32m[✓] Processus de configuration du fichier .env termine !\033[0m\n"; \
	else \
		printf "\033[1;32m[✓] Fichier .env deja existant. (Configurations conservees)\033[0m\n"; \
	fi

uninstall:
	@echo "Desinstallation de blackbox (peut necessiter les droits administrateur/sudo)..."
	@rm -f /usr/local/bin/blackbox
	@printf "\033[1;32m[✓] Desinstallation terminee !\033[0m\n"
