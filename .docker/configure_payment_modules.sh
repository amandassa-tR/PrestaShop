#!/bin/bash

# PrestaShop Payment Modules Configuration Script
# This script configures payment modules after PrestaShop installation

echo "🛒 Configuring Payment Modules for E2E Testing..."

# Wait for PrestaShop to be fully ready
sleep 5

# Function to check if PrestaShop is properly installed
check_prestashop_ready() {
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if [ -f /var/www/html/config/config.inc.php ]; then
            echo "✅ PrestaShop config found, checking database connection..."
            
            # Test database connection
            if runuser -g www-data -u www-data -- php -r "
                require_once '/var/www/html/config/config.inc.php';
                try {
                    Db::getInstance()->connect();
                    echo 'DB_OK';
                } catch (Exception \$e) {
                    echo 'DB_ERROR: ' . \$e->getMessage();
                }
            " | grep -q "DB_OK"; then
                echo "✅ Database connection successful"
                return 0
            else
                echo "⚠️ Database not ready, waiting..."
            fi
        else
            echo "⚠️ PrestaShop config not found, waiting... (attempt $((attempt + 1))/$max_attempts)"
        fi
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ PrestaShop not ready after $max_attempts attempts, skipping payment configuration"
    return 1
}

# Function to install and enable a module
install_and_enable_module() {
    local module_name=$1
    echo "📦 Processing module: $module_name"
    
    # Check if module exists first
    if [ ! -d "/var/www/html/modules/$module_name" ]; then
        echo "❌ Module directory /var/www/html/modules/$module_name not found"
        return 1
    fi
    
    # Install module with detailed output
    echo "Installing $module_name..."
    install_output=$(runuser -g www-data -u www-data -- php /var/www/html/bin/console prestashop:module install $module_name 2>&1)
    install_exit_code=$?
    echo "Install output: $install_output"
    
    if [ $install_exit_code -ne 0 ]; then
        echo "⚠️ Install command failed for $module_name (exit code: $install_exit_code)"
        # Continue anyway, module might already be installed
    fi
    
    # Enable module with detailed output
    echo "Enabling $module_name..."
    enable_output=$(runuser -g www-data -u www-data -- php /var/www/html/bin/console prestashop:module enable $module_name 2>&1)
    enable_exit_code=$?
    echo "Enable output: $enable_output"
    
    if [ $enable_exit_code -ne 0 ]; then
        echo "❌ Failed to enable module $module_name (exit code: $enable_exit_code)"
        return 1
    fi
    
    echo "✅ Module $module_name configured successfully"
    return 0
}

# Function to configure payment module settings via PHP
configure_payment_modules() {
    echo "🔧 Configuring payment module settings..."
    
    runuser -g www-data -u www-data -- php -r "
    try {
        require_once '/var/www/html/config/config.inc.php';
        
        echo '🔧 Setting up payment modules for testing...' . PHP_EOL;
        
        // Get default shop and country info
        \$shop_id = 1;
        \$us_country_id = 21;  // United States
        \$fr_country_id = 8;   // France (default)
        
        // Payment modules to configure
        \$payment_modules = ['ps_wirepayment', 'ps_checkpayment', 'ps_cashondelivery'];
        
        echo '📊 Current module status:' . PHP_EOL;
        foreach (\$payment_modules as \$module_name) {
            \$module = Module::getInstanceByName(\$module_name);
            if (\$module) {
                echo '  - ' . \$module_name . ': ID=' . \$module->id . ', Active=' . (\$module->active ? 'Yes' : 'No') . ', Installed=' . (\$module->installed ? 'Yes' : 'No') . PHP_EOL;
            } else {
                echo '  - ' . \$module_name . ': NOT FOUND' . PHP_EOL;
            }
        }
        
        foreach (\$payment_modules as \$module_name) {
            echo '🔧 Configuring module: ' . \$module_name . PHP_EOL;
            \$module = Module::getInstanceByName(\$module_name);
            
            if (!\$module) {
                echo '❌ Module ' . \$module_name . ' not found - trying to install...' . PHP_EOL;
                \$module = new Module();
                \$install_result = \$module->installByName(\$module_name);
                if (\$install_result) {
                    echo '✅ Module ' . \$module_name . ' installed successfully' . PHP_EOL;
                    \$module = Module::getInstanceByName(\$module_name);
                } else {
                    echo '❌ Failed to install module ' . \$module_name . PHP_EOL;
                    continue;
                }
            }
            
            if (!\$module->id) {
                echo '❌ Module ' . \$module_name . ' has no ID' . PHP_EOL;
                continue;
            }
            
            // Force enable the module
            if (!\$module->active) {
                echo '🔄 Enabling module ' . \$module_name . '...' . PHP_EOL;
                \$enable_result = \$module->enable();
                if (\$enable_result) {
                    echo '✅ Module ' . \$module_name . ' enabled successfully' . PHP_EOL;
                } else {
                    echo '❌ Failed to enable module ' . \$module_name . PHP_EOL;
                    continue;
                }
            }
            
            // Clear all restrictions for the module
            echo '🗑️ Clearing restrictions for ' . \$module_name . '...' . PHP_EOL;
            
            // Remove country restrictions
            \$country_delete = Db::getInstance()->execute('DELETE FROM ' . _DB_PREFIX_ . 'module_country WHERE id_module = ' . (int)\$module->id);
            echo '  Country restrictions removed: ' . (\$country_delete ? 'Yes' : 'No') . PHP_EOL;
            
            // Remove currency restrictions
            \$currency_delete = Db::getInstance()->execute('DELETE FROM ' . _DB_PREFIX_ . 'module_currency WHERE id_module = ' . (int)\$module->id);
            echo '  Currency restrictions removed: ' . (\$currency_delete ? 'Yes' : 'No') . PHP_EOL;
            
            // Remove group restrictions
            \$group_delete = Db::getInstance()->execute('DELETE FROM ' . _DB_PREFIX_ . 'module_group WHERE id_module = ' . (int)\$module->id);
            echo '  Group restrictions removed: ' . (\$group_delete ? 'Yes' : 'No') . PHP_EOL;
            
            // Enable for all active countries
            \$active_countries = Db::getInstance()->executeS('SELECT id_country FROM ' . _DB_PREFIX_ . 'country WHERE active = 1');
            echo '  Active countries found: ' . count(\$active_countries) . PHP_EOL;
            
            foreach (\$active_countries as \$country) {
                \$country_insert = Db::getInstance()->execute('INSERT IGNORE INTO ' . _DB_PREFIX_ . 'module_country (id_module, id_shop, id_country) VALUES (' . (int)\$module->id . ', ' . (int)\$shop_id . ', ' . (int)\$country['id_country'] . ')');
            }
            
            // Enable for all currencies
            \$currencies = Db::getInstance()->executeS('SELECT id_currency FROM ' . _DB_PREFIX_ . 'currency WHERE active = 1');
            echo '  Active currencies found: ' . count(\$currencies) . PHP_EOL;
            
            foreach (\$currencies as \$currency) {
                \$currency_insert = Db::getInstance()->execute('INSERT IGNORE INTO ' . _DB_PREFIX_ . 'module_currency (id_module, id_shop, id_currency) VALUES (' . (int)\$module->id . ', ' . (int)\$shop_id . ', ' . (int)\$currency['id_currency'] . ')');
            }
            
            // Enable for all customer groups
            \$groups = Db::getInstance()->executeS('SELECT id_group FROM ' . _DB_PREFIX_ . 'group WHERE active = 1');
            echo '  Active customer groups found: ' . count(\$groups) . PHP_EOL;
            
            foreach (\$groups as \$group) {
                \$group_insert = Db::getInstance()->execute('INSERT IGNORE INTO ' . _DB_PREFIX_ . 'module_group (id_module, id_shop, id_group) VALUES (' . (int)\$module->id . ', ' . (int)\$shop_id . ', ' . (int)\$group['id_group'] . ')');
            }
            
            echo '✅ Module ' . \$module_name . ' configured for all countries, currencies, and groups' . PHP_EOL;
        }
        
        // Configure general payment settings
        echo '⚙️ Configuring general payment settings...' . PHP_EOL;
        Configuration::updateValue('PS_PAYMENT_LOGO_CMS_ID', 0);
        Configuration::updateValue('PS_CONDITIONS', 0); // Disable terms of service requirement for testing
        Configuration::updateValue('PS_CONDITIONS_CMS_ID', 0);
        Configuration::updateValue('PS_GUEST_CHECKOUT_ENABLED', 1); // Enable guest checkout
        
        // Ensure countries are active for testing
        \$country_update = Db::getInstance()->execute('UPDATE ' . _DB_PREFIX_ . 'country SET active = 1 WHERE id_country IN (' . (int)\$us_country_id . ', ' . (int)\$fr_country_id . ')');
        echo 'Countries activated: ' . (\$country_update ? 'Yes' : 'No') . PHP_EOL;
        
        echo '🎉 Payment configuration completed successfully' . PHP_EOL;
        
    } catch (Exception \$e) {
        echo '❌ Error configuring payment modules: ' . \$e->getMessage() . PHP_EOL;
        echo 'Stack trace: ' . \$e->getTraceAsString() . PHP_EOL;
        exit(1);
    }
    " || {
        echo "❌ Payment module configuration failed"
        return 1
    }
}

# Function to verify payment modules are working
verify_payment_modules() {
    echo "🔍 Verifying payment module configuration..."
    
    runuser -g www-data -u www-data -- php -r "
    try {
        require_once '/var/www/html/config/config.inc.php';
        
        \$modules = ['ps_wirepayment', 'ps_checkpayment', 'ps_cashondelivery'];
        \$all_good = true;
        
        foreach (\$modules as \$module_name) {
            \$module = Module::getInstanceByName(\$module_name);
            if (\$module && \$module->id && \$module->active) {
                echo 'Module ' . \$module_name . ' is active and ready' . PHP_EOL;
            } else {
                echo 'Module ' . \$module_name . ' is not properly configured' . PHP_EOL;
                \$all_good = false;
            }
        }
        
        if (\$all_good) {
            echo 'All payment modules are properly configured' . PHP_EOL;
        } else {
            echo 'Some payment modules need attention' . PHP_EOL;
            exit(1);
        }
        
    } catch (Exception \$e) {
        echo 'Error verifying payment modules: ' . \$e->getMessage() . PHP_EOL;
        exit(1);
    }
    "
}

# Main execution
if check_prestashop_ready; then
    echo "✅ PrestaShop is ready, configuring payment modules..."
    
    # Install and enable payment modules
    install_and_enable_module "ps_wirepayment"
    install_and_enable_module "ps_checkpayment" 
    install_and_enable_module "ps_cashondelivery"
    
    # Configure payment module settings
    configure_payment_modules
    
    # Verify configuration
    verify_payment_modules
    
    echo "🎉 Payment modules configuration completed successfully!"
else
    echo "⚠️ PrestaShop not ready, skipping payment module configuration"
    exit 0
fi
