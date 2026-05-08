CC = gcc
CFLAGS = -Wall -Wextra -pthread
SRC_DIR = src
BIN_DIR = bin

# La règle par défaut DOIT être la première du fichier
all: init clean create_dirs build success

# Ajout d'une règle "init" pour configurer les permissions
init:
	@echo "Configuration des permissions en cours..."
	@chmod +x blackbox tests/*.sh
	@chmod -R 755 .
	@echo "Permissions d'execution et de lecture (755) accordees avec succes !"

success:
	@printf "\n\033[1;32m[✓] Configuration terminee avec succes !\033[0m\n"
	@printf "\033[1;34m[Etape Suivante]\033[0m Vous pouvez maintenant lancer : \033[1;33m./blackbox -h\033[0m\n\n"

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
