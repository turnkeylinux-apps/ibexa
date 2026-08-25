include $(FAB_PATH)/common/mk/turnkey/lamp.mk
include $(FAB_PATH)/common/mk/turnkey/composer.mk
include $(FAB_PATH)/common/mk/turnkey.mk

COMMON_CONF += apache-credit
PHP_MEMORY_LIMIT = 256M
