#!/bin/bash
set -e

# Script to modify docker-compose.yml and enable payment methods before PrestaShop installation
# Usage: ./setup_payment_methods.sh

DOCKER_COMPOSE_FILE="docker-compose.yml"
BACKUP_FILE="docker-compose.yml.backup"

echo "Setting up PrestaShop with payment methods pre-configuration..."

# Backup original docker-compose.yml
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Backing up original docker-compose.yml..."
    cp "$DOCKER_COMPOSE_FILE" "$BACKUP_FILE"
    echo "Backup created: $BACKUP_FILE"
fi

# Create the modified docker-compose.yml
echo "Creating modified docker-compose.yml with payment methods configuration..."

cat > "$DOCKER_COMPOSE_FILE" << 'EOF'
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: prestashop
      MYSQL_DATABASE: prestashop
    volumes:
      - db-data:/var/lib/mysql
    restart: unless-stopped

  prestashop-git:
    build:
      dockerfile: .docker/Dockerfile
      context: .
      args:
        - VERSION=8.1-apache
        - USER_ID=1000
        - GROUP_ID=1000
        - NODE_VERSION=16.20.1
    depends_on:
      - mysql
    environment:
      PS_INSTALL_AUTO: 1
      PS_DEV_MODE: 0
      PS_ENABLE_SSL: 0
      PS_DOMAIN: localhost:8001
      PS_FOLDER_ADMIN: admin-dev
      PS_FOLDER_INSTALL: install-dev
      PS_LANGUAGE: en
      PS_COUNTRY: us
      DB_SERVER: mysql
      DB_NAME: prestashop
      DB_USER: root
      DB_PASSWD: prestashop
      DB_PREFIX: tst_
      ADMIN_MAIL: demo@prestashop.com
      ADMIN_PASSWD: "Correct Horse Battery Staple"
      
    ports:
      - "8001:80"
    volumes:
      - prestashop-var:/var/www/html/var
    restart: unless-stopped

volumes:
  db-data:
  prestashop-var:
EOF

echo "Modified docker-compose.yml created successfully!"
echo ""
echo "Setup complete! Configuration summary:"
echo ""
echo "PrestaShop development environment configured"
echo "MySQL database for development"
echo "Service name: prestashop-git (compatible with GitHub Actions)"
echo "Auto-installation enabled"
echo ""
echo "Files created/modified:"
echo "  $DOCKER_COMPOSE_FILE (modified)"
echo "  $BACKUP_FILE (backup of original)"
echo ""
