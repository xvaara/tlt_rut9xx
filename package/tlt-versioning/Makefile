include $(TOPDIR)/rules.mk

PKG_NAME:=tlt-versioning
PKG_RELEASE:=1
PKG_VERSION:=1

#PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/tlt-versioning
	SECTION:=base
	CATEGORY:=Base system
	TITLE:=Teltonika version file
	MENU:=1
endef

define Package/tlt-versioning/description
 Enable this option in order to include file containing Teltonika firmware version.
endef

define Package/tlt-versioning/config
	source "$(SOURCE)/Config.in"
endef

define Build/Compile
endef

define Package/tlt-versioning/install
	@-rm $(PKG_BUILD_DIR)/.built; \
	echo RUT9XX_$(CONFIG_TLT_VERSIONING_RELEASE)_$(CONFIG_TLT_VERSIONING_CLIENT).$(CONFIG_TLT_VERSIONING_MAJOR).$(CONFIG_TLT_VERSIONING_MINOR) > ./files/version; \
	$(INSTALL_DIR) $(1)/etc/
	$(INSTALL_BIN) ./files/version $(1)/etc/version; \
	rm -f ./files/version;
endef

ifneq ($(CONFIG_TLT_VERSIONING_MINOR_ENABLE),y)
	CONFIG_TLT_VERSIONING_MINOR:="700"
endif

$(eval $(call BuildPackage,tlt-versioning))
