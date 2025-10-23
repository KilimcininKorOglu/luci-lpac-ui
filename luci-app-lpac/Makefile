# Copyright (C) 2025 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-lpac
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-3.0
PKG_MAINTAINER:=Your Name <your.email@example.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-lpac
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for lpac eSIM management
  DEPENDS:=+luci-base +lpac +luci-lib-jsonc
  PKGARCH:=all
endef

define Package/luci-app-lpac/description
  Web interface for managing eSIM profiles using lpac
endef

define Build/Compile
endef

define Package/luci-app-lpac/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/*.lua $(1)/usr/lib/lua/luci/controller/

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/lpac
	$(INSTALL_DATA) ./luasrc/model/lpac/*.lua $(1)/usr/lib/lua/luci/model/lpac/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/lpac
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/lpac/*.js \
		$(1)/www/luci-static/resources/view/lpac/

	$(INSTALL_DIR) $(1)/www/luci-static/resources
	$(INSTALL_DATA) ./htdocs/luci-static/resources/*.css \
		$(1)/www/luci-static/resources/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/lpac $(1)/etc/config/

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/* $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,luci-app-lpac))
