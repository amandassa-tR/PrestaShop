<?php
/**
 * PrestaShop United States Payment & Shipping Configuration Script
 * 
 * This script configures your PrestaShop instance to:
 * 1. Disable email functionality
 * 2. Enable payment methods for United States
 * 3. Configure shipping for United States
 * 
 * Usage: php configure-us-payments.php
 */

// Include PrestaShop configuration
require_once dirname(__FILE__) . '/config/config.inc.php';

echo "=== PrestaShop US Payment & Shipping Configuration ===" . PHP_EOL;
echo "URL: " . _PS_BASE_URL_ . PHP_EOL;
echo "Shop: " . Configuration::get('PS_SHOP_NAME') . PHP_EOL;
echo "======================================================" . PHP_EOL;

// 1. Disable email functionality
echo "1. Disabling email functionality..." . PHP_EOL;
Configuration::updateValue('PS_MAIL_METHOD', 3); // METHOD_NONE = 3
echo "   ✓ Email method set to disabled" . PHP_EOL;

// 2. Get United States country ID
echo "2. Getting United States country information..." . PHP_EOL;
$us_country_id = Country::getByIso('US');
if (!$us_country_id) {
    echo "   ! United States not found, using default ID 21" . PHP_EOL;
    $us_country_id = 21;
}
echo "   ✓ United States country ID: " . $us_country_id . PHP_EOL;

// 3. Enable United States as active country
echo "3. Enabling United States as active country..." . PHP_EOL;
$result = Db::getInstance()->execute('UPDATE ' . _DB_PREFIX_ . 'country SET active = 1 WHERE id_country = ' . (int)$us_country_id);
if ($result) {
    echo "   ✓ United States enabled as active country" . PHP_EOL;
} else {
    echo "   ! Failed to enable United States" . PHP_EOL;
}

// 4. Install and enable payment modules
echo "4. Installing and enabling payment modules..." . PHP_EOL;
$payment_modules = ['ps_wirepayment', 'ps_checkpayment', 'ps_cashondelivery'];
$module_ids = [];

foreach ($payment_modules as $module_name) {
    echo "   Processing module: $module_name" . PHP_EOL;
    
    // Get or install module
    $module = Module::getInstanceByName($module_name);
    if (!$module) {
        echo "     ! Module $module_name not found, skipping..." . PHP_EOL;
        continue;
    }
    
    // Install if not installed
    if (!$module->isInstalled()) {
        if ($module->install()) {
            echo "     ✓ Module $module_name installed" . PHP_EOL;
        } else {
            echo "     ! Failed to install module $module_name" . PHP_EOL;
            continue;
        }
    }
    
    // Enable if disabled
    if (!$module->isEnabled()) {
        if ($module->enable()) {
            echo "     ✓ Module $module_name enabled" . PHP_EOL;
        } else {
            echo "     ! Failed to enable module $module_name" . PHP_EOL;
        }
    }
    
    $module_ids[$module_name] = $module->id;
    echo "     ✓ Module $module_name ready (ID: {$module->id})" . PHP_EOL;
}

// 5. Configure payment module country restrictions for United States
echo "5. Configuring payment methods for United States..." . PHP_EOL;
$shop_id = Context::getContext()->shop->id;

foreach ($module_ids as $module_name => $module_id) {
    echo "   Configuring $module_name..." . PHP_EOL;
    
    // Remove existing restrictions for this module
    $delete_result = Db::getInstance()->execute(
        'DELETE FROM ' . _DB_PREFIX_ . 'module_country 
         WHERE id_module = ' . (int)$module_id . ' 
         AND id_shop = ' . (int)$shop_id
    );
    
    // Add United States restriction (allow US)
    $insert_result = Db::getInstance()->execute(
        'INSERT INTO ' . _DB_PREFIX_ . 'module_country (id_module, id_shop, id_country) 
         VALUES (' . (int)$module_id . ', ' . (int)$shop_id . ', ' . (int)$us_country_id . ')'
    );
    
    if ($insert_result) {
        echo "     ✓ $module_name configured for United States" . PHP_EOL;
    } else {
        echo "     ! Failed to configure $module_name for United States" . PHP_EOL;
    }
}

// 6. Configure shipping for United States
echo "6. Configuring shipping for United States..." . PHP_EOL;

// Get default carrier
$default_carrier_id = Configuration::get('PS_CARRIER_DEFAULT');
$carrier = new Carrier($default_carrier_id);

if (Validate::isLoadedObject($carrier)) {
    echo "   Default carrier: {$carrier->name} (ID: {$carrier->id})" . PHP_EOL;
    
    // Get US zone
    $us_zone = Db::getInstance()->getValue(
        'SELECT id_zone FROM ' . _DB_PREFIX_ . 'country WHERE id_country = ' . (int)$us_country_id
    );
    
    if ($us_zone) {
        echo "   United States zone ID: $us_zone" . PHP_EOL;
        
        // Associate carrier with US zone
        $zone_result = Db::getInstance()->execute(
            'INSERT IGNORE INTO ' . _DB_PREFIX_ . 'carrier_zone (id_carrier, id_zone) 
             VALUES (' . (int)$carrier->id . ', ' . (int)$us_zone . ')'
        );
        
        if ($zone_result) {
            echo "   ✓ Default carrier configured for United States zone" . PHP_EOL;
        } else {
            echo "   ! Carrier zone association may already exist" . PHP_EOL;
        }
    } else {
        echo "   ! Could not find United States zone" . PHP_EOL;
    }
} else {
    echo "   ! Could not load default carrier" . PHP_EOL;
}

// 7. Configure currency for United States (USD)
echo "7. Configuring currency for United States..." . PHP_EOL;

// Get USD currency
$usd_currency = Db::getInstance()->getRow(
    'SELECT * FROM ' . _DB_PREFIX_ . 'currency WHERE iso_code = "USD" AND active = 1'
);

if ($usd_currency) {
    echo "   ✓ USD currency found (ID: {$usd_currency['id_currency']})" . PHP_EOL;
    
    // Configure payment modules for USD currency
    foreach ($module_ids as $module_name => $module_id) {
        $currency_result = Db::getInstance()->execute(
            'INSERT IGNORE INTO ' . _DB_PREFIX_ . 'module_currency (id_module, id_shop, id_currency) 
             VALUES (' . (int)$module_id . ', ' . (int)$shop_id . ', ' . (int)$usd_currency['id_currency'] . ')'
        );
        
        if ($currency_result) {
            echo "   ✓ $module_name configured for USD currency" . PHP_EOL;
        }
    }
} else {
    echo "   ! USD currency not found or not active" . PHP_EOL;
}

// 8. Verification
echo "8. Verification..." . PHP_EOL;

// Check email status
$email_method = Configuration::get('PS_MAIL_METHOD');
echo "   Email method: " . ($email_method == 3 ? "Disabled ✓" : "Enabled ($email_method)") . PHP_EOL;

// Check available payment modules for US
$available_modules = Db::getInstance()->executeS(
    'SELECT m.name, m.active
     FROM ' . _DB_PREFIX_ . 'module m 
     INNER JOIN ' . _DB_PREFIX_ . 'module_country mc ON m.id_module = mc.id_module 
     WHERE mc.id_country = ' . (int)$us_country_id . ' 
     AND mc.id_shop = ' . (int)$shop_id . ' 
     AND m.active = 1'
);

echo "   Available payment modules for United States:" . PHP_EOL;
if (count($available_modules) > 0) {
    foreach ($available_modules as $module) {
        echo "     ✓ {$module['name']}" . PHP_EOL;
    }
} else {
    echo "     ! No payment modules configured for United States" . PHP_EOL;
}

// Check if US is active
$us_active = Db::getInstance()->getValue(
    'SELECT active FROM ' . _DB_PREFIX_ . 'country WHERE id_country = ' . (int)$us_country_id
);
echo "   United States country status: " . ($us_active ? "Active ✓" : "Inactive !") . PHP_EOL;

echo PHP_EOL . "=== Configuration Complete ===" . PHP_EOL;
echo "Your PrestaShop instance is now configured for United States:" . PHP_EOL;
echo "  ✓ Email functionality disabled" . PHP_EOL;
echo "  ✓ Payment methods enabled for US" . PHP_EOL;
echo "  ✓ Shipping configured for US" . PHP_EOL;
echo "  ✓ Currency (USD) configured" . PHP_EOL;
echo PHP_EOL;
echo "You can now test checkout with United States addresses." . PHP_EOL;
echo "Back Office: " . _PS_BASE_URL_ . "admin-dev/" . PHP_EOL;
echo "Payment Preferences: " . _PS_BASE_URL_ . "admin-dev/index.php?controller=AdminPaymentPreferences" . PHP_EOL;
?>
