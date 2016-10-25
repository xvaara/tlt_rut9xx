include $(TOPDIR)/rules.mk

PKG_NAME:=ddns-tlt
PKG_VERSION:=1.0.0
PKG_RELEASE:=22

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/ddns-tlt
	SECTION:=net
	CATEGORY:=Network
        SUBMENU:=IP Addresses and Names
	TITLE:=Dynamic DNS Scripts
	PKGARCH:=all
endef

define Package/ddns-tlt/description
	A highly configurable set of scripts for doing
	dynamic dns updates
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/ddns-tlt/conffiles
/etc/config/ddns
endef

define Package/ddns-tlt/install
	$(INSTALL_DIR) $(1)
	chmod 755 $(1)
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,ddns-tlt))
