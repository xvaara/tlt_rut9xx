#
# Copyright (C) 2013 Teltonika
#

include $(TOPDIR)/rules.mk

PKG_NAME:=teltonika-snmpd
PKG_VERSION:=5.4.2.1
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/teltonika-snmpd
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Custom SNMP daemon provided by Teltonika
  DEPENDS:=+libelf
endef

define Package/teltonika-snmpd/description
 Simple Network Management Protocol (SNMP) is a widely used protocol for
 monitoring the health and welfare of network equipment (eg. routers),
 computer equipment and even devices like UPSs. teltonika-snmpd is a custom
 SNMP daemon implementing SNMP v1, SNMP v2c and SNMP v3 using both
 IPv4 and IPv6 with GSM extensions in MIB2.
endef

SNMP_MIB_MODULES_INCLUDED = \
	host/hr_device \
	host/hr_disk \
	host/hr_filesys \
	host/hr_network \
	host/hr_partition \
	host/hr_proc \
	host/hr_storage \
	host/hr_system \
	ieee802dot11 \
	if-mib/ifXTable \
	mibII/at \
	mibII/icmp \
	mibII/ifTable \
	mibII/ip \
	mibII/snmp_mib \
	mibII/sysORTable \
	mibII/system_mib \
	mibII/tcp \
	mibII/udp \
	mibII/vacm_context \
	mibII/vacm_vars \
	snmpv3/snmpEngine \
	snmpv3/snmpMPDStats \
	snmpv3/usmConf \
	snmpv3/usmStats \
	snmpv3/usmUser \
	tunnel \
	teltonika \
	ucd-snmp/disk \
	ucd-snmp/dlmod \
	ucd-snmp/extensible \
	ucd-snmp/loadave \
	ucd-snmp/memory \
	ucd-snmp/pass \
	ucd-snmp/proc \
	ucd-snmp/vmstat \
	util_funcs \
	utilities/execute \
	examples/notification\

SNMP_MIB_MODULES_EXCLUDED = \
	agent_mibs \
	agentx \
	disman/event \
	disman/schedule \
	hardware \
	host \
	if-mib \
	mibII \
	notification \
	notification-log-mib \
	snmpv3mibs \
	target \
	tcp-mib \
	ucd_snmp \
	udp-mib \
	utilities \

SNMP_TRANSPORTS_INCLUDED = Callback UDP

SNMP_TRANSPORTS_EXCLUDED = TCP TCPIPv6 Unix

TARGET_CFLAGS += $(FPIC)

CONFIGURE_ARGS += \
	--enable-mfd-rewrites \
	--enable-shared \
	--disable-ipv6 \
	--enable-static \
	--with-endianness=little \
	--with-logfile=/var/log/snmpd.log \
	--with-persistent-directory=/usr/lib/snmp/ \
	--with-default-snmp-version=1 \
	--with-sys-contact=root@localhost \
	--with-sys-location=Unknown \
	--enable-applications \
	--disable-debugging \
	--disable-manuals \
	--disable-scripts \
	--with-mib-modules="$(SNMP_MIB_MODULES_INCLUDED)" \
	--with-out-transports="$(SNMP_TRANSPORTS_EXCLUDED)" \
	--with-transports="$(SNMP_TRANSPORTS_INCLUDED)" \
	--without-openssl \
	--without-libwrap \
	--without-rpm \
	--without-zlib \
	 $(call autoconf_bool,CONFIG_IPV6,ipv6) \

ifeq ($(CONFIG_IPV6),y)
SNMP_TRANSPORTS_INCLUDED+= UDPIPv6
endif

TARGET_LDFLAGS += -L$(TOOLCHAIN_DIR)/usr/lib

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Configure
	$(call Build/Configure/Default)
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		INSTALL_PREFIX="$(PKG_INSTALL_DIR)" \
		LDFLAGS="$(TARGET_LDFLAGS) -lm -lc" \
		all install
	# we will use statically linked daemon
	$(MAKE) -C $(PKG_BUILD_DIR)/agent \
		LDFLAGS="$(TARGET_LDFLAGS) -lm -static" \
		EXEEXT="-static" \
		snmpd-static
endef

define Package/teltonika-snmpd/conffiles
/etc/default/snmpd
/etc/config/snmpd
endef

define Package/teltonika-snmpd/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/snmpd.conf $(1)/etc/config/snmpd
	$(INSTALL_DIR) $(1)/etc/snmp
	ln -sf /var/run/snmpd.conf $(1)/etc/snmp/
	$(INSTALL_DIR) $(1)/etc/default
	$(INSTALL_DATA) ./files/snmpd.default $(1)/etc/default/snmpd
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/snmpd.init $(1)/etc/init.d/snmpd
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/agent/snmpd-static $(1)/usr/sbin/snmpd
	$(INSTALL_BIN) ./files/sysget $(1)/usr/sbin/sysget
	$(INSTALL_DIR) $(1)/usr/opt/snmp/mibs
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mibs/TELTONIKA-MIB.txt $(1)/usr/opt/snmp/mibs/TELTONIKA-MIB.txt
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/hotspot_user_info.lua $(1)/usr/sbin/hotspot_user_info.lua
endef

$(eval $(call BuildPackage,teltonika-snmpd))
