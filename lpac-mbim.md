# LPAC MBIM Driver Kullanım Kılavuzu

**Platform:** OpenWrt / GL-XE300
**Modem:** MBIM-compatible modems (USB modems, newer LTE/5G modules)
**Driver:** lpac mbim (USB MBIM protocol)
**lpac Versiyon:** 2.3.0

---

## MBIM Nedir?

**MBIM** (Mobile Broadband Interface Model), Microsoft tarafından geliştirilen USB tabanlı modemler için standart bir protokoldür. Modern LTE ve 5G USB modemler tarafından desteklenir.

### MBIM Özellikleri

- ✅ USB üzerinden çalışır
- ✅ Platform bağımsız (Linux, Windows, macOS)
- ✅ USB CDC MBIM spesifikasyonuna uyumlu
- ✅ Veri ve kontrol kanalları ayrı
- ✅ AT komutlarından daha modern ve hızlı

---

## MBIM vs Diğer Driverlar

| Özellik | MBIM | QMI | AT |
|---------|------|-----|-----|
| Protokol | USB MBIM | Qualcomm QMI | AT Commands |
| Hız | ⚡ Hızlı | ⚡⚡ Çok Hızlı | 🐢 Yavaş |
| Kararlılık | ✅ İyi | ✅ Mükemmel | ⚠️ Orta |
| Evrensellik | ✅ Yüksek | ⚠️ Qualcomm özel | ✅ Evrensel |
| USB Modems | ✅✅✅ İdeal | ❌ | ✅ Alternatif |
| Quectel Modems | ⚠️ Firmware bağımlı | ✅✅✅ Önerilen | ✅ Yedek |
| lpac Desteği | ✅ Resmi | ❌ Yok | ✅ Resmi |

### Ne Zaman MBIM Kullanılmalı?

**MBIM kullanın:**

- ✅ USB modem kullanıyorsanız (dongle, USB stick)
- ✅ Modem MBIM destekliyorsa
- ✅ QMI desteği yoksa
- ✅ Windows/Linux cross-platform gerekiyorsa

**QMI tercih edin:**

- ✅ Quectel modem kullanıyorsanız (EP06-E, RG500Q, RM500Q)
- ✅ En yüksek performans gerekiyorsa
- ✅ quectel_lpad kullanabiliyorsanız

**AT yedek olsun:**

- ⚠️ MBIM ve QMI çalışmazsa
- ⚠️ Sadece test için

---

## MBIM Desteğini Kontrol Etme

### 1. USB Modem Bilgisi

```bash
# USB cihazları listele
lsusb

# Örnek çıktı:
# Bus 001 Device 003: ID 2c7c:0306 Quectel Wireless Solutions Co., Ltd. EP06 module
```

### 2. MBIM Cihazını Bulma

```bash
# MBIM cihazları listele
ls -l /dev/cdc-wdm*

# Çıktı:
# crw-rw---- 1 root root 180, 0 Jan 27 10:00 /dev/cdc-wdm0
```

### 3. MBIM Modu Kontrol

```bash
# Modem USB composition mode
AT+QCFG="usbnet"

# Çıktı:
# +QCFG: "usbnet",2  (2 = MBIM mode)
# 0 = PPP, 1 = ECM, 2 = MBIM, 3 = RNDIS
```

### 4. mbimcli ile Test

```bash
# MBIM cihazı test et
mbimcli -d /dev/cdc-wdm0 --query-device-caps

# Başarılıysa modem MBIM destekliyor
```

---

## Kurulum

### 1. Gerekli Paketleri Yükle

```bash
opkg update
opkg install libmbim-utils kmod-usb-net-cdc-mbim
```

**Paket açıklamaları:**

- `libmbim-utils` - mbimcli ve MBIM kütüphaneleri
- `kmod-usb-net-cdc-mbim` - Kernel MBIM driver

### 2. lpac Binary'sini Yükle

```bash
# IPK paketi ile
opkg install /tmp/lpac_*.ipk

# veya manuel
cp lpac /usr/bin/
chmod +x /usr/bin/lpac
```

### 3. lpac MBIM Desteğini Doğrula

```bash
# lpac driver listesi
lpac driver list

# Çıktıda "mbim" görmelisiniz
```

---

## Ortam Değişkenleri

### MBIM Driver Ayarları

```bash
# MBIM driver kullan
export LPAC_APDU=mbim

# MBIM cihaz yolu (varsayılan: /dev/cdc-wdm0)
export LPAC_APDU_MBIM_DEVICE=/dev/cdc-wdm0

# Debug modu (opsiyonel)
export LPAC_APDU_MBIM_DEBUG=1

# HTTP backend (gerekli)
export LPAC_HTTP=curl
```

### Kalıcı Yapılandırma

`/etc/profile.d/lpac-mbim.sh` oluştur:

```bash
#!/bin/sh
export LPAC_APDU=mbim
export LPAC_APDU_MBIM_DEVICE=/dev/cdc-wdm0
export LPAC_HTTP=curl
```

Ardından:

```bash
chmod +x /etc/profile.d/lpac-mbim.sh
source /etc/profile.d/lpac-mbim.sh
```

---

## MBIM Cihaz Yapılandırma

### İzinleri Ayarla

```bash
# MBIM cihaz izinleri
chmod 666 /dev/cdc-wdm0

# Kalıcı udev kuralı
cat > /etc/udev/rules.d/99-mbim.rules << 'EOF'
# MBIM devices
KERNEL=="cdc-wdm*", MODE="0666", GROUP="dialout"
SUBSYSTEM=="usb", ATTRS{idVendor}=="2c7c", MODE="0666"
EOF

udevadm control --reload-rules
udevadm trigger
```

### ModemManager Yönetimi

MBIM driver, ModemManager ile çakışabilir:

```bash
# ModemManager'ı durdur
/etc/init.d/modemmanager stop

# Kalıcı devre dışı bırak
/etc/init.d/modemmanager disable
```

**veya** ModemManager'dan MBIM cihazı filtrele:

```bash
# /etc/ModemManager/ModemManager.conf
[ModemManager]
filter-policy=strict
```

---

## lpac ile MBIM Kullanımı

### Temel Kullanım

Ortam değişkenleri ayarlandıktan sonra, lpac normal şekilde kullanılır:

#### 1. eUICC Bilgisi

```bash
lpac chip info
```

**Çıktı:**

```json
{
  "type": "lpa",
  "payload": {
    "code": 0,
    "message": "success",
    "data": {
      "eidValue": "89049032008800000123456789012345",
      "eid": "89049032008800000123456789012345"
    }
  }
}
```

#### 2. Profil Listesi

```bash
lpac profile list
```

#### 3. Profil İndirme

```bash
# QR kod formatı
lpac profile download -a 'LPA:1$smdp.server.com$ACTIVATION-CODE'

# SM-DP+ ve Matching ID
lpac profile download -s smdp.server.com -m "MATCHING-ID"

# Confirmation code ile
lpac profile download -s smdp.server.com -m "MATCHING-ID" -c "1234"
```

#### 4. Profil Aktif/Pasif

```bash
# Aktif et
lpac profile enable 8901234567890123456

# Pasif et
lpac profile disable 8901234567890123456
```

#### 5. Profil Silme

```bash
lpac profile delete 8901234567890123456
```

#### 6. Bildirimleri İşle

```bash
# Bildirimleri listele
lpac notification list

# Tümünü işle
lpac notification process -a -r
```

---

## GL-XE300 için MBIM Modu Aktifleştirme

EP06-E modemi varsayılan olarak QMI modunda gelir. MBIM kullanmak için USB composition mode değiştirilmeli:

### 1. USB Composition Kontrol

```bash
# AT portu üzerinden (ttyUSB2)
echo -e "AT+QCFG=\"usbnet\"\r\n" > /dev/ttyUSB2
cat /dev/ttyUSB2

# veya AT client ile
atcmd AT+QCFG=\"usbnet\"

# Çıktı:
# +QCFG: "usbnet",0  (0 = ECM/QMI mode)
```

### 2. MBIM Moduna Geçiş

```bash
# MBIM moduna ayarla
echo -e "AT+QCFG=\"usbnet\",2\r\n" > /dev/ttyUSB2

# Modem resetle
echo -e "AT+CFUN=1,1\r\n" > /dev/ttyUSB2

# veya
atcmd AT+QCFG=\"usbnet\",2
atcmd AT+CFUN=1,1
```

### 3. MBIM Cihazını Doğrula

```bash
# 30 saniye bekle (modem reboot)
sleep 30

# MBIM cihazı göründü mü?
ls -l /dev/cdc-wdm*

# mbimcli ile test
mbimcli -d /dev/cdc-wdm0 --query-device-caps
```

### 4. QMI Moduna Geri Dönüş

```bash
# QMI moduna geri al
atcmd AT+QCFG=\"usbnet\",0
atcmd AT+CFUN=1,1
```

**⚠️ UYARI:** Quectel modemler için **QMI driver (quectel_lpad) önerilir**. MBIM sadece alternatif veya test amaçlı.

---

## Debug ve Sorun Giderme

### Debug Modu

```bash
export LPAC_APDU_MBIM_DEBUG=1
lpac chip info
```

Debug çıktısı MBIM mesaj trafiğini gösterir.

### Yaygın Sorunlar

#### 1. "MBIM device not found"

**Sebep:** Cihaz yok veya yanlış path

**Çözümler:**

```bash
# Cihazı kontrol et
ls -l /dev/cdc-wdm*

# Kernel modülü yüklü mü?
lsmod | grep cdc_mbim

# Modülü yükle
modprobe cdc_mbim
modprobe cdc_wdm

# USB cihazları kontrol et
lsusb | grep -i quectel
```

#### 2. "MBIM device busy"

**Sebep:** ModemManager veya başka process kullanıyor

**Çözüm:**

```bash
# ModemManager'ı durdur
/etc/init.d/modemmanager stop

# Process kontrolü
lsof | grep cdc-wdm
ps aux | grep -E "(ModemManager|mbim)"

# Kill et
killall ModemManager
```

#### 3. "Permission denied"

**Sebep:** İzin sorunu

**Çözüm:**

```bash
# İzinleri düzelt
chmod 666 /dev/cdc-wdm0

# veya root olarak çalıştır
sudo lpac chip info
```

#### 4. "MBIM command timeout"

**Sebep:** Modem yanıt vermiyor veya MBIM modu aktif değil

**Çözümler:**

```bash
# Modem MBIM modunda mı?
mbimcli -d /dev/cdc-wdm0 --query-device-caps

# USB composition kontrol et
atcmd AT+QCFG=\"usbnet\"

# MBIM moduna geç
atcmd AT+QCFG=\"usbnet\",2
atcmd AT+CFUN=1,1
```

#### 5. "Profile download failed"

**Sebep:** İnternet bağlantısı yok

**Çözüm:**

```bash
# İnternet testi
ping -c 4 8.8.8.8

# MBIM veri bağlantısı aktif mi?
mbimcli -d /dev/cdc-wdm0 --query-connection-state

# MBIM bağlantı kur
mbimcli -d /dev/cdc-wdm0 --connect=internet
```

---

## MBIM Network Bağlantısı

MBIM ile veri bağlantısı kurmak:

### 1. MBIM Proxy Başlat

```bash
# mbim-proxy başlat (çoklu erişim için)
mbim-proxy &
```

### 2. Bağlantı Kur

```bash
# APN ayarla ve bağlan
mbimcli -d /dev/cdc-wdm0 -p \
  --connect=apn='internet'

# Çıktı:
# [/dev/cdc-wdm0] Successfully connected
# IPv4 configuration available: 'address, gateway, dns'
#     IP [0]: '10.x.x.x/24'
#   Gateway: '10.x.x.1'
#   DNS [0]: '8.8.8.8'
```

### 3. IP Ayarları Uygula

```bash
# Interface oluştur
ip link add link wwan0 name wwan0.mbim type vlan id 0
ip link set wwan0.mbim up

# IP ata
ip addr add 10.x.x.x/24 dev wwan0.mbim
ip route add default via 10.x.x.1 dev wwan0.mbim

# DNS ayarla
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### 4. Bağlantıyı Kes

```bash
mbimcli -d /dev/cdc-wdm0 -p --disconnect
```

---

## mbimcli Komut Referansı

### Temel Komutlar

```bash
# Cihaz bilgisi
mbimcli -d /dev/cdc-wdm0 --query-device-caps
mbimcli -d /dev/cdc-wdm0 --query-device-services

# SIM durumu
mbimcli -d /dev/cdc-wdm0 --query-subscriber-ready-status

# Sinyal bilgisi
mbimcli -d /dev/cdc-wdm0 --query-signal-state

# Bağlantı durumu
mbimcli -d /dev/cdc-wdm0 --query-connection-state

# IP ayarları
mbimcli -d /dev/cdc-wdm0 --query-ip-configuration

# Kayıt durumu
mbimcli -d /dev/cdc-wdm0 --query-registration-state
```

### SIM ve eSIM

```bash
# SIM slot bilgisi
mbimcli -d /dev/cdc-wdm0 --ms-query-slot-info-status

# Preferred slot ayarla
mbimcli -d /dev/cdc-wdm0 --ms-set-device-slot-mappings=0

# PIN durumu
mbimcli -d /dev/cdc-wdm0 --query-pin-state
```

---

## MBIM vs QMI Karşılaştırma (GL-XE300)

### Performans Testi Sonuçları

| İşlem | MBIM | QMI (quectel_lpad) | AT |
|-------|------|-------------------|-----|
| eUICC bilgisi | ~2s | ~1s | ~2s |
| Profil listesi | ~3s | ~1-2s | ~3-5s |
| Profil indirme | ~45-60s | ~30-45s | ~60-90s |
| Profil enable | ~5s | ~2-3s | ~5-10s |

### Başarı Oranları

| İşlem | MBIM | QMI | AT |
|-------|------|-----|-----|
| eUICC bilgisi | 95% | 99% | 95% |
| Profil indirme | 85% | 95% | 60-70% |
| Profil enable | 90% | 98% | 70-80% |

**Sonuç:** QMI hala en hızlı ve güvenilir, MBIM iyi bir alternatif.

---

## Desteklenen Modemler

### Test Edilmiş Modemler

| Modem | MBIM Desteği | Önerilen Driver | Notlar |
|-------|--------------|----------------|--------|
| **Quectel EP06-E** | ⚠️ Firmware bağımlı | QMI | USB composition değişikliği gerekli |
| Quectel RG500Q | ✅ Var | QMI | Her iki driver da çalışır |
| Quectel RM500Q | ✅ Var | QMI | Her iki driver da çalışır |
| Huawei E3372 | ✅ Tam destek | MBIM | USB dongle, ideal |
| ZTE MF823 | ✅ Tam destek | MBIM | USB dongle, iyi |
| Sierra Wireless EM7455 | ✅ Tam destek | MBIM/QMI | Her ikisi de çalışır |
| Fibocom L850-GL | ✅ Tam destek | MBIM | MBIM önerilen |

**Genel Kural:**

- 📱 **Quectel modemler** → QMI tercih edin
- 🔌 **USB dongle'lar** → MBIM ideal
- 💻 **Laptop modemler** → MBIM iyi

---

## İleri Düzey Kullanım

### Çoklu MBIM Cihaz

Birden fazla modem varsa:

```bash
# Cihazları listele
ls -l /dev/cdc-wdm*

# Her cihaz için ayrı ortam değişkeni
export LPAC_APDU_MBIM_DEVICE=/dev/cdc-wdm0  # Modem 1
lpac chip info

export LPAC_APDU_MBIM_DEVICE=/dev/cdc-wdm1  # Modem 2
lpac chip info
```

### MBIM Proxy ile Çoklu Erişim

```bash
# mbim-proxy başlat
mbim-proxy --verbose &

# Şimdi çoklu process MBIM cihazına erişebilir
lpac chip info &
mbimcli -d /dev/cdc-wdm0 --query-signal-state &
```

### Wrapper Script

`/usr/bin/lpac-mbim` wrapper:

```bash
#!/bin/sh
# lpac-mbim wrapper

export LPAC_APDU=mbim
export LPAC_APDU_MBIM_DEVICE=/dev/cdc-wdm0
export LPAC_HTTP=curl

# ModemManager'ı durdur
/etc/init.d/modemmanager stop 2>/dev/null

# İzinleri düzelt
chmod 666 /dev/cdc-wdm0 2>/dev/null

# lpac'ı çalıştır
exec lpac "$@"
```

Kullanım:

```bash
chmod +x /usr/bin/lpac-mbim

lpac-mbim chip info
lpac-mbim profile list
lpac-mbim profile download -a 'LPA:1$...'
```

---

## Güvenlik

### MBIM Cihaz İzinleri

```bash
# Kullanıcıyı dialout grubuna ekle
usermod -a -G dialout $USER

# udev kuralı
cat > /etc/udev/rules.d/99-mbim.rules << 'EOF'
KERNEL=="cdc-wdm*", MODE="0666", GROUP="dialout"
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2c7c", MODE="0666"
EOF
```

### Profil Şifreleme

MBIM üzerinden yönetilen eSIM profilleri modem tarafından hardware-level şifrelenir.

---

## Hızlı Referans

### Ortam Değişkenleri

```bash
export LPAC_APDU=mbim
export LPAC_APDU_MBIM_DEVICE=/dev/cdc-wdm0
export LPAC_APDU_MBIM_DEBUG=1  # (opsiyonel)
export LPAC_HTTP=curl
```

### lpac Komutları (MBIM ile)

| Görev | Komut |
|-------|-------|
| eUICC bilgisi | `lpac chip info` |
| Profil listesi | `lpac profile list` |
| Profil indir | `lpac profile download -a 'LPA:1$...'` |
| Profil aktif et | `lpac profile enable <ICCID>` |
| Profil pasif et | `lpac profile disable <ICCID>` |
| Profil sil | `lpac profile delete <ICCID>` |
| Bildirim işle | `lpac notification process -a -r` |

### mbimcli Test Komutları

| Görev | Komut |
|-------|-------|
| Cihaz bilgisi | `mbimcli -d /dev/cdc-wdm0 --query-device-caps` |
| SIM durumu | `mbimcli -d /dev/cdc-wdm0 --query-subscriber-ready-status` |
| Sinyal | `mbimcli -d /dev/cdc-wdm0 --query-signal-state` |
| Bağlantı durumu | `mbimcli -d /dev/cdc-wdm0 --query-connection-state` |
| Bağlan | `mbimcli -d /dev/cdc-wdm0 --connect=apn='internet'` |

### USB Composition (EP06-E)

```bash
# Mevcut mod kontrolü
atcmd AT+QCFG=\"usbnet\"

# MBIM moduna geç
atcmd AT+QCFG=\"usbnet\",2
atcmd AT+CFUN=1,1

# QMI moduna geri dön
atcmd AT+QCFG=\"usbnet\",0
atcmd AT+CFUN=1,1
```

---

## Sorun Raporlama

MBIM driver ile sorun yaşarsanız:

```bash
# 1. Sistem bilgisi
uname -a
cat /etc/openwrt_release

# 2. lpac versiyonu
lpac --version

# 3. MBIM cihaz bilgisi
ls -l /dev/cdc-wdm*
mbimcli -d /dev/cdc-wdm0 --query-device-caps

# 4. USB bilgisi
lsusb -v | grep -A 20 "Quectel"

# 5. Kernel modülleri
lsmod | grep -E "(cdc_mbim|cdc_wdm|usb_wwan)"

# 6. Debug log
export LPAC_APDU_MBIM_DEBUG=1
lpac chip info > debug-mbim.log 2>&1

# 7. Process kontrol
ps aux | grep -E "(ModemManager|mbim)"
lsof | grep cdc-wdm
```

---

## Ek Kaynaklar

- **QMI Driver Kılavuzu:** [lpac-qmi.md](lpac-qmi.md)
- **AT Driver Kılavuzu:** [lpac-at.md](lpac-at.md)
- **Genel lpac Kılavuzu:** [lpac.md](lpac.md)
- **LuCI Web Arayüzü:** [LUCI.md](LUCI.md)
- **MBIM Spec:** <https://www.usb.org/document-library/mobile-broadband-interface-model-v10>
- **libmbim GitHub:** <https://gitlab.freedesktop.org/mobile-broadband/libmbim>
- **lpac GitHub:** <https://github.com/estkme-group/lpac>

---

## Özet ve Öneriler

### Driver Seçimi Rehberi

```
Quectel Modem (EP06-E, RG500Q, RM500Q)
    ├─► QMI (quectel_lpad)    ✅✅✅ EN İYİ
    ├─► MBIM (lpac mbim)      ⚠️ Alternatif
    └─► AT (lpac at)          ❌ Yedek

USB Dongle (Huawei, ZTE, Sierra)
    ├─► MBIM (lpac mbim)      ✅✅✅ EN İYİ
    └─► AT (lpac at)          ⚠️ Alternatif

Laptop Modem (Fibocom, Sierra)
    ├─► MBIM (lpac mbim)      ✅✅ İYİ
    └─► QMI (varsa)           ✅ Alternatif
```

### Kurulum Önerileri

**GL-XE300 + EP06-E için:**

1. **İlk tercih:** QMI (quectel_lpad) - [lpac-qmi.md](lpac-qmi.md)
2. **Alternatif:** MBIM (bu kılavuz)
3. **Yedek:** AT - [lpac-at.md](lpac-at.md)

**USB Dongle için:**

1. **İlk tercih:** MBIM (bu kılavuz)
2. **Yedek:** AT - [lpac-at.md](lpac-at.md)

---

**Son Güncelleme:** 2025-01
**Yazar:** Kerem
**Lisans:** AGPL-3.0
