# Payment Modules Pre-Install System

This documentation describes the automated payment modules configuration system for PrestaShop E2E testing environments.

## Overview

The payment modules pre-install system automatically configures essential payment modules during PrestaShop installation, ensuring that payment options are available immediately when the frontend store is accessible.

## How It Works

### 1. Installation Flow
```
Docker Container Start → PrestaShop CLI Installation → Payment Modules Configuration → Frontend Ready
```

### 2. Configured Modules
- **ps_wirepayment** - Wire/Bank Transfer Payment
- **ps_checkpayment** - Check Payment  
- **ps_cashondelivery** - Cash on Delivery

### 3. Configuration Applied
- ✅ Modules installed and enabled
- ✅ Available for all countries (no geographic restrictions)
- ✅ Available for all currencies (no currency restrictions)  
- ✅ Available for all customer groups (no group restrictions)
- ✅ Terms of service requirement disabled for testing
- ✅ Countries activated for testing (US, France)

## Files Modified

### Core Script
- **`.docker/configure_payment_modules.sh`** - Main configuration script

### Docker Setup
- **`.docker/docker_run_git.sh`** - Calls payment script after installation
- **`.docker/Dockerfile`** - Copies script to container
- **`docker-compose.yml`** - Adds environment variable
- **`docker-compose.mariadb.yml`** - Adds environment variable

### CI/CD Integration  
- **`.github/actions/setup-env/action.yml`** - Enables configuration in CI
- **`.github/workflows/sanity.yml`** - Simplified verification

## Environment Variables

### `PS_CONFIGURE_PAYMENT_MODULES`
- **Default**: `1` (enabled)
- **Values**: `1` (enable) or `0` (disable)
- **Purpose**: Controls whether payment modules are automatically configured

## Usage

### Automatic (Default)
Payment modules are configured automatically during docker container startup:
```bash
docker compose up
```

### Manual Control
To disable automatic configuration:
```bash
PS_CONFIGURE_PAYMENT_MODULES=0 docker compose up
```

### Verification
Check if payment modules are properly configured:
```bash
docker exec prestashop-prestashop-git-1 php -r "
require_once '/var/www/html/config/config.inc.php';
foreach (['ps_wirepayment', 'ps_checkpayment', 'ps_cashondelivery'] as \$name) {
  \$module = Module::getInstanceByName(\$name);
  echo \$name . ': ' . (\$module && \$module->active ? 'Active' : 'Inactive') . PHP_EOL;
}
"
```

## Benefits

### 🚀 **Faster Setup**
- Payment options available immediately after installation
- No manual post-installation configuration required

### 🔒 **More Reliable** 
- Configuration happens during installation process
- Prevents frontend accessibility issues from module configuration
- Consistent setup across all environments

### 🧪 **Better Testing**
- All payment methods available for E2E testing
- No geographic or currency restrictions
- Simplified test scenarios

## Troubleshooting

### Payment Options Not Visible
1. Check if modules are active:
   ```bash
   docker exec prestashop-prestashop-git-1 php bin/console prestashop:module list --filter=payment
   ```

2. Verify configuration script ran:
   ```bash
   docker logs prestashop-prestashop-git-1 | grep "Payment modules"
   ```

3. Manual configuration (if needed):
   ```bash
   docker exec prestashop-prestashop-git-1 bash /tmp/configure_payment_modules.sh
   ```

### Disable Auto-Configuration
If you need to disable automatic payment configuration:
1. Set environment variable: `PS_CONFIGURE_PAYMENT_MODULES=0`
2. Or modify the script to exit early
3. Restart container: `docker compose restart prestashop-git`

## Integration with CI/CD

The system is fully integrated with GitHub Actions workflows:
- Enabled by default in `.github/actions/setup-env/action.yml`
- Verified in `.github/workflows/sanity.yml`
- Works with both MySQL and MariaDB configurations

## Security Notes

⚠️ **Testing Only**: This configuration is designed for testing environments only. Do not use in production as it:
- Disables terms of service requirements
- Removes geographic restrictions  
- Enables all payment methods globally

For production deployments, configure payment modules manually according to your business requirements.
