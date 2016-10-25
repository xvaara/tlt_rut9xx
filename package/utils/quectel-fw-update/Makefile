#
# Copyright (C) 2006-2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=quectel-fw-update
PKG_VERSION:=0.0.1
PKG_BUILD_DIR:=$(BUILD_DIR)/quectel-fw-update

include $(INCLUDE_DIR)/package.mk

define Package/quectel-fw-update
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Quectel EC20 firmware update tool by Teltonika
  DEPENDS:=+libstdcpp +libusb-1.0
endef

define Package/quectel-fw-update/description
  Test package template by Teltonika
endef

#CONFIGURE_ARGS = ''
	
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

define Package/quectel-fw-update/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/quectelFlasher $(1)/usr/sbin/quectelFlasher
endef

$(eval $(call BuildPackage,quectel-fw-update))
