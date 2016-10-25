#
# Copyright (C) 2014 Tetlonika
#

include $(TOPDIR)/rules.mk

PKG_NAME:=smpp_package
PKG_VERSION:=0.0.1
PKG_BUILD_DIR:=$(BUILD_DIR)/smpp_package

include $(INCLUDE_DIR)/package.mk

define Package/smpp_package
	SECTION:=base
	CATEGORY:=Base system
	TITLE:=smpp_c_deamon
endef

define Package/smpp_package/description
	smpp transmitter
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
	$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) \
		$(TARGET_CONFIGURE_OPTS)
endef

define Build/InstallDev
endef

define Package/smpp_package/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/smpp $(1)/usr/sbin/smpp
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/smpp_init $(1)/etc/init.d/smpp_init
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/smpp_config $(1)/etc/config/smpp_config
	
	chmod 755 $(1)/etc/init.d/smpp_init
endef

$(eval $(call BuildPackage,smpp_package))
