# Copyright (C) 2025 OpenWrt.org
#
# This is free software, licensed under the MIT License.
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for eSIM Profile Management (LPAC)
LUCI_DEPENDS:=+luci-base +luci-compat
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-lpac
PKG_VERSION:=1.0.1
PKG_RELEASE:=82
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Kilimcinin Kör Oğlu <k@keremgok.tr>

define Package/luci-app-lpac/conffiles
/etc/config/lpac
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
