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
      MYSQL_ROOT_PASSWORD: admin
      MYSQL_DATABASE: prestashop
    volumes:
      - db-data:/var/lib/mysql
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-padmin"]
      timeout: 20s
      retries: 10

  prestashop:
    image: prestashop/prestashop:latest
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      # Installation flags
      PS_INSTALL_AUTO: 1
      PS_DEV_MODE: 0
      
      # Database configuration  
      DB_SERVER: mysql
      DB_NAME: prestashop
      DB_USER: root
      DB_PASSWD: admin

      # Admin credentials
      ADMIN_MAIL: demo@prestashop.com
      ADMIN_PASSWD: "Correct Horse Battery Staple"

      # PrestaShop configuration
      PS_FOLDER_ADMIN: backoffice
      PS_DOMAIN: "137.184.105.135:8080"
      PS_COUNTRY: us
      PS_LANGUAGE: en
      
      # Enable SSL and demo data
      PS_ENABLE_SSL: 0
      PS_INSTALL_DEMO_PRODUCTS: 1
      
    ports:
      - "8080:80"
    volumes:
      - prestashop-var:/var/www/html/var
      - prestashop-modules:/var/www/html/modules
      - prestashop-themes:/var/www/html/themes
      - prestashop-override:/var/www/html/override
      - ./scripts:/tmp/scripts:ro
    command: >
      bash -c "
        echo 'Starting PrestaShop with payment methods setup...'
        
        # Wait for database to be ready
        echo 'Waiting for database...'
        while ! mysqladmin ping -h mysql -u root -padmin --silent; do
          echo 'Database not ready, waiting...'
          sleep 2
        done
        echo 'Database ready!'
        
        # Start Apache in background
        apache2-foreground &
        APACHE_PID=\$$!
        
        # Wait for PrestaShop installation to complete
        echo 'Waiting for PrestaShop installation...'
        timeout=300
        counter=0
        while [ \$$counter -lt \$$timeout ]; do
          if [ -f /var/www/html/config/settings.inc.php ]; then
            echo 'PrestaShop installation detected!'
            break
          fi
          echo 'Installation not complete, waiting... (\$$counter/\$$timeout)'
          sleep 5
          counter=\$$((counter + 5))
        done
        
        if [ \$$counter -ge \$$timeout ]; then
          echo 'Installation timeout reached'
          exit 1
        fi
        
        # Wait a bit more for services to be fully ready
        echo 'Waiting for services to stabilize...'
        sleep 10
        
        echo 'Configuring payment methods and settings...'
        
        # Disable IP check for testing reliability  
        php /var/www/html/bin/console prestashop:config set PS_COOKIE_CHECKIP --value='0' || echo 'Warning: Could not disable IP check'
        
        # Enable wire payment for US
        php /var/www/html/bin/console prestashop:module install ps_wirepayment || echo 'Wire payment already installed'
        php /var/www/html/bin/console prestashop:module enable ps_wirepayment || echo 'Warning: Could not enable wire payment'
        
        # Enable check payment for US
        php /var/www/html/bin/console prestashop:module install ps_checkpayment || echo 'Check payment already installed'  
        php /var/www/html/bin/console prestashop:module enable ps_checkpayment || echo 'Warning: Could not enable check payment'
        
        # Enable cash on delivery for US
        php /var/www/html/bin/console prestashop:module install ps_cashondelivery || echo 'Cash on delivery already installed'
        php /var/www/html/bin/console prestashop:module enable ps_cashondelivery || echo 'Warning: Could not enable cash on delivery'
        
        # Configure payment restrictions for United States
        mysql -h mysql -u root -padmin prestashop -e \"
          -- Enable United States if not already enabled
          UPDATE ps_country SET active = 1 WHERE iso_code = 'US';
          
          -- Configure wire payment for US
          INSERT IGNORE INTO ps_module_country (id_module, id_shop, id_country) 
          SELECT m.id_module, 1, c.id_country 
          FROM ps_module m, ps_country c 
          WHERE m.name = 'ps_wirepayment' AND c.iso_code = 'US';
          
          -- Configure check payment for US  
          INSERT IGNORE INTO ps_module_country (id_module, id_shop, id_country)
          SELECT m.id_module, 1, c.id_country 
          FROM ps_module m, ps_country c 
          WHERE m.name = 'ps_checkpayment' AND c.iso_code = 'US';
          
          -- Configure cash on delivery for US
          INSERT IGNORE INTO ps_module_country (id_module, id_shop, id_country)
          SELECT m.id_module, 1, c.id_country 
          FROM ps_module m, ps_country c 
          WHERE m.name = 'ps_cashondelivery' AND c.iso_code = 'US';
          
          -- Set US as default country for shipping
          INSERT IGNORE INTO ps_carrier_zone (id_carrier, id_zone)
          SELECT c.id_carrier, z.id_zone 
          FROM ps_carrier c, ps_zone z, ps_country co
          WHERE co.iso_code = 'US' AND z.id_zone = co.id_zone AND c.active = 1;
        \" || echo 'Warning: Could not configure payment restrictions'
        
        echo 'Payment methods configuration completed!'
        echo 'PrestaShop is ready at: http://137.184.105.135:8080'
        echo 'Admin panel at: http://137.184.105.135:8080/backoffice'
        echo 'Admin credentials: demo@prestashop.com / Correct Horse Battery Staple'
        
        # Keep Apache running in foreground
        wait \$$APACHE_PID
      "
    restart: unless-stopped

volumes:
  db-data:
  prestashop-var:
  prestashop-modules:
  prestashop-themes:
  prestashop-override:
EOF

echo "Modified docker-compose.yml created successfully!"

# Create scripts directory if it doesn't exist
mkdir -p scripts

# Create additional configuration script
cat > scripts/additional_config.sh << 'EOF'
#!/bin/bash
# Additional configuration script for advanced payment setup

echo "Running additional payment configuration..."

# Configure payment method details
php /var/www/html/bin/console prestashop:config set PS_BANK_WIRE_DETAILS --value="Bank: PrestaShop Bank\nAccount: 1234567890\nRouting: 987654321"
php /var/www/html/bin/console prestashop:config set PS_CHECK_PAYMENT_DETAILS --value="Please send checks to:\nPrestaShop Store\n123 Commerce St\nShop City, SC 12345"

echo "Additional configuration completed!"
EOF

chmod +x scripts/additional_config.sh

echo ""
echo "Setup complete! Configuration summary:"
echo ""
echo "MySQL database with health check"
echo "PrestaShop with auto-installation" 
echo "Payment methods: Wire Transfer, Check Payment, Cash on Delivery"
echo "US country enabled for payments"
echo "IP check disabled (PS_COOKIE_CHECKIP = 0)"
echo "Demo products installed"
echo ""
echo "To start PrestaShop:"
echo "  docker-compose up -d"
echo ""
echo "Access URLs:"
echo "  Frontend: http://137.184.105.135:8080"
echo "  Admin:    http://137.184.105.135:8080/backoffice"
echo ""
echo "Admin Credentials:"
echo "  Email:    demo@prestashop.com"
echo "  Password: Correct Horse Battery Staple"
echo ""
echo "Files created/modified:"
echo "  $DOCKER_COMPOSE_FILE (modified)"
echo "  $BACKUP_FILE (backup of original)"
echo "  scripts/additional_config.sh (additional configuration)"
echo ""
