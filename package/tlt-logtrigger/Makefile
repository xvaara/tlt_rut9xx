# 
# Copyright (C) 2006 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=tlt-logtrigger
PKG_RELEASE:=04
PKG_VERSION:=1.$(PKG_RELEASE)

PKG_BUILD_DIR:=$(BUILD_DIR)/tlt-logtrigger

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/tlt-logtrigger
  SECTION:=Utils
  CATEGORY:=Utilities
  DEPENDS:=libuci libubox libubus libblobmsg-json
  TITLE:=logtrigger help you to monitor syslog and run some script for all or specific log event 
endef

TARGET_CPPFLAGS := \
	-I$(STAGING_DIR)/usr/include/ \
	-I$(LINUX_DIR)/include \
	-Wall \
	$(TARGET_CPPFLAGS)

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	CFLAGS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
	$(MAKE) -C $(PKG_BUILD_DIR) \
		$(TARGET_CONFIGURE_OPTS) \
		LIBS="$(TARGET_LDFLAGS) -lm -luci -lubox -lubus -lblobmsg_json"
endef

define Package/tlt-logtrigger/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/logtrigger
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/logtrigger.init $(1)/etc/init.d/logtrigger
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/logtrigger $(1)/usr/bin/logtrigger
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/info.sh $(1)/etc/logtrigger/info.sh
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/ipblock.sh $(1)/etc/logtrigger/ipblock.sh
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/logtrigger.conf $(1)/etc/config/logtrigger
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/blocklist.conf $(1)/etc/config/blocklist
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/firewall.sh $(1)/etc/logtrigger/firewall.sh
endef

$(eval $(call BuildPackage,tlt-logtrigger))
