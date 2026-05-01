#!/bin/bash

# Dossier de destination
TARGET_DIR="$(dirname "$0")/sample_logs"
mkdir -p "$TARGET_DIR"

echo "Génération des fichiers de logs Nginx simulés..."

# Création d'un bloc de logs diversifié (plusieurs IPs, codes 200, 403, 404, 500, 502)
cat << 'EOF' > "$TARGET_DIR/base_chunk.log"
192.168.1.10 - - [21/Apr/2026:14:30:00 +0000] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
10.0.0.5 - - [21/Apr/2026:14:30:01 +0000] "GET /admin/config.php HTTP/1.1" 403 512 "-" "Mozilla/5.0 (X11; Linux x86_64)"
8.8.8.8 - - [21/Apr/2026:14:30:02 +0000] "POST /api/v1/login HTTP/1.1" 500 256 "-" "curl/7.68.0"
172.16.0.2 - - [21/Apr/2026:14:30:03 +0000] "GET /images/logo.png HTTP/1.1" 200 4096 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X)"
192.168.1.20 - - [21/Apr/2026:14:30:04 +0000] "GET /hidden-page.html HTTP/1.1" 404 128 "-" "Nmap/7.80"
10.0.0.5 - - [21/Apr/2026:14:30:05 +0000] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0 (X11; Linux x86_64)"
172.16.0.2 - - [21/Apr/2026:14:30:06 +0000] "GET /api/status HTTP/1.1" 502 512 "-" "curl/7.68.0"
192.168.1.10 - - [21/Apr/2026:14:30:07 +0000] "GET /css/style.css HTTP/1.1" 200 3072 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
9.9.9.9 - - [21/Apr/2026:14:30:08 +0000] "GET /wp-login.php HTTP/1.1" 403 512 "-" "Python-urllib/3.8"
192.168.1.10 - - [21/Apr/2026:14:30:09 +0000] "POST /upload HTTP/1.1" 500 1024 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
EOF

# 1. Génération de nginx_access_small.log (~1 Mo)
echo "Création de nginx_access_small.log (~1 Mo)..."
cp "$TARGET_DIR/base_chunk.log" "$TARGET_DIR/nginx_access_small.log"
# Doubler la taille à partir du bloc de base
for i in {1..12}; do
    cat "$TARGET_DIR/nginx_access_small.log" > "$TARGET_DIR/tmp_small.log"
    cat "$TARGET_DIR/tmp_small.log" >> "$TARGET_DIR/nginx_access_small.log"
done
rm "$TARGET_DIR/tmp_small.log"

# 2. Génération de nginx_access_medium.log (~50 Mo)
echo "Création de nginx_access_medium.log (~50 Mo)..."
cp "$TARGET_DIR/nginx_access_small.log" "$TARGET_DIR/nginx_access_medium.log"
# Doubler pour atteindre ~50 Mo
for i in {1..6}; do
    cat "$TARGET_DIR/nginx_access_medium.log" > "$TARGET_DIR/tmp_medium.log"
    cat "$TARGET_DIR/tmp_medium.log" >> "$TARGET_DIR/nginx_access_medium.log"
done
rm "$TARGET_DIR/tmp_medium.log"

# 3. Génération de nginx_access_large.log (taille réduite à ~128 Mo)
echo "Création de nginx_access_large.log (~128 Mo)..."
cp "$TARGET_DIR/nginx_access_medium.log" "$TARGET_DIR/nginx_access_large.log"
# Doubler pour atteindre ~128 Mo (au lieu de 500 Mo pour économiser de l'espace)
for i in {1..1}; do
    cat "$TARGET_DIR/nginx_access_large.log" > "$TARGET_DIR/tmp_large.log"
    cat "$TARGET_DIR/tmp_large.log" >> "$TARGET_DIR/nginx_access_large.log"
done
rm "$TARGET_DIR/tmp_large.log"
rm "$TARGET_DIR/base_chunk.log"

echo "Génération terminée !"
echo "Tailles des fichiers créés :"
ls -lh "$TARGET_DIR"
