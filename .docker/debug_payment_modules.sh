#!/bin/bash

# Debug script for payment modules configuration
echo "🔍 Payment Modules Debug Script"
echo "==============================="

echo ""
echo "1. Container Environment Variables:"
echo "   PS_CONFIGURE_PAYMENT_MODULES: ${PS_CONFIGURE_PAYMENT_MODULES:-'not set'}"

echo ""
echo "2. PrestaShop Configuration Status:"
if [ -f /var/www/html/config/config.inc.php ]; then
    echo "   ✅ config.inc.php exists"
    
    # Check database connection
    echo "   Database connection test:"
    runuser -g www-data -u www-data -- php -r "
    try {
        require_once '/var/www/html/config/config.inc.php';
        Db::getInstance()->connect();
        echo '   ✅ Database connection successful\n';
    } catch (Exception \$e) {
        echo '   ❌ Database connection failed: ' . \$e->getMessage() . '\n';
    }
    "
else
    echo "   ❌ config.inc.php not found"
fi

echo ""
echo "3. Payment Module Files Status:"
for module in ps_wirepayment ps_checkpayment ps_cashondelivery; do
    if [ -d "/var/www/html/modules/$module" ]; then
        echo "   ✅ $module directory exists"
        if [ -f "/var/www/html/modules/$module/$module.php" ]; then
            echo "      ✅ Main module file exists"
        else
            echo "      ❌ Main module file missing"
        fi
    else
        echo "   ❌ $module directory not found"
    fi
done

echo ""
echo "4. Database Module Status:"
if [ -f /var/www/html/config/config.inc.php ]; then
    runuser -g www-data -u www-data -- php -r "
    try {
        require_once '/var/www/html/config/config.inc.php';
        
        echo '   Modules in database:\n';
        \$modules = ['ps_wirepayment', 'ps_checkpayment', 'ps_cashondelivery'];
        foreach (\$modules as \$module_name) {
            \$module = Module::getInstanceByName(\$module_name);
            if (\$module) {
                echo '   - ' . \$module_name . ': ID=' . (\$module->id ?: 'NULL') . 
                     ', Active=' . (\$module->active ? 'Yes' : 'No') . 
                     ', Installed=' . (\$module->installed ? 'Yes' : 'No') . '\n';
                     
                // Check database restrictions
                if (\$module->id) {
                    \$countries = Db::getInstance()->getValue('SELECT COUNT(*) FROM ' . _DB_PREFIX_ . 'module_country WHERE id_module = ' . (int)\$module->id);
                    \$currencies = Db::getInstance()->getValue('SELECT COUNT(*) FROM ' . _DB_PREFIX_ . 'module_currency WHERE id_module = ' . (int)\$module->id);
                    \$groups = Db::getInstance()->getValue('SELECT COUNT(*) FROM ' . _DB_PREFIX_ . 'module_group WHERE id_module = ' . (int)\$module->id);
                    
                    echo '     Restrictions: Countries=' . \$countries . ', Currencies=' . \$currencies . ', Groups=' . \$groups . '\n';
                }
            } else {
                echo '   - ' . \$module_name . ': NOT FOUND\n';
            }
        }
        
        echo '\n   General payment settings:\n';
        echo '   - PS_CONDITIONS: ' . Configuration::get('PS_CONDITIONS') . '\n';
        echo '   - PS_GUEST_CHECKOUT_ENABLED: ' . Configuration::get('PS_GUEST_CHECKOUT_ENABLED') . '\n';
        
    } catch (Exception \$e) {
        echo '   ❌ Error checking database: ' . \$e->getMessage() . '\n';
    }
    "
fi

echo ""
echo "5. Configuration Script Status:"
if [ -f /tmp/configure_payment_modules.sh ]; then
    echo "   ✅ Payment configuration script exists"
    echo "   Permissions: $(ls -la /tmp/configure_payment_modules.sh)"
    
    echo ""
    echo "6. Running Configuration Script Manually:"
    bash /tmp/configure_payment_modules.sh
else
    echo "   ❌ Payment configuration script not found"
fi

echo ""
echo "Debug completed."
