# lpac Driver Kullanım Kılavuzu

Bu dokümanda lpac uygulamasının farklı APDU backend'lerini nasıl kullanacağınız açıklanmaktadır.

## Aktif Driver'lar

Şu anda lpac'ta aşağıdaki driver'lar aktif durumdadır:

### APDU Backend'leri:
- ✅ **AT Backend** (`LPAC_WITH_APDU_AT = ON`)
- ✅ **UQMI Backend** (`LPAC_WITH_APDU_UQMI = ON`)
- ❌ **PCSC Backend** (`LPAC_WITH_APDU_PCSC = OFF`)
- ❌ **QMI Backend** (`LPAC_WITH_APDU_QMI = OFF`)
- ❌ **MBIM Backend** (`LPAC_WITH_APDU_MBIM = OFF`)

### HTTP Backend'leri:
- ✅ **cURL** (`LPAC_WITH_HTTP_CURL = ON`)

---

## 1. AT Backend

### ⚠️ UYARI
**AT Backend sadece DEMO amaçlı kullanılmalıdır!**

- Bazı operasyonlar (download, delete vb.) başarısız olabilir
- Maximum response time 300ms (çoğu eUICC operasyonu için yetersiz)
- Sadece ETSI TS 127 007 spesifikasyonuna uygun istekler desteklenir

### AT Backend Çeşitleri

#### 1. `at` - Managed Channel
AT+{CCHO,CCHC,CGLA} komutlarını kullanır.

```bash
export LPAC_APDU=at
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB0
lpac profile list
```

#### 2. `at_csim` - Unmanaged Channel
AT+CSIM komutunu kullanır.

```bash
export LPAC_APDU=at_csim
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB0
lpac profile list
```

### Environment Variables

| Variable | Açıklama | Default Değer |
|----------|----------|---------------|
| `LPAC_APDU` | Backend seçimi | - |
| `LPAC_APDU_AT_DEVICE` | Serial port device | `/dev/ttyUSB0` (Unix)<br>`COM3` (Windows) |
| `LPAC_APDU_AT_DEBUG` | Debug çıktısı | `false` |

### Gereksinimler

**Donanım/Sistem:**
- Serial port erişimi (`/dev/ttyUSB0`, `/dev/ttyACM0` vb.)
- AT komutlarını destekleyen modem
- Non-root kullanıcı için `dialout` grubuna eklenme gerekir

**Serial Port İzinleri (Linux):**
```bash
# Kullanıcıyı dialout grubuna ekle
sudo usermod -a -G dialout $USER

# Yeniden giriş yap veya:
newgrp dialout
```

---

## 2. UQMI Backend (Önerilen - OpenWrt)

**OpenWrt için en uygun backend seçimidir.**

### Avantajları
- ✅ QMI kaynakları üzerinde çakışma yok
- ✅ Güvenilir operasyonlar
- ✅ Timeout problemi yok
- ✅ OpenWrt için optimize edilmiş

### Kullanım

```bash
export LPAC_APDU=uqmi
export LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0
export LPAC_APDU_QMI_UIM_SLOT=1
lpac profile list
```

### Environment Variables

| Variable | Açıklama | Default Değer |
|----------|----------|---------------|
| `LPAC_APDU` | Backend seçimi | - |
| `LPAC_APDU_QMI_DEVICE` | QMI device yolu | `/dev/cdc-wdm0` |
| `LPAC_APDU_QMI_UIM_SLOT` | UIM slot numarası (1'den başlar) | `1` |
| `LPAC_APDU_UQMI_DEBUG` | Debug çıktısı | `false` |
| `LPAC_APDU_UQMI_PROGRAM` | uqmi binary yolu | `uqmi` |

### Gereksinimler

**OpenWrt Paketleri:**
```bash
opkg update
opkg install uqmi
opkg install libcurl
opkg install kmod-usb-net-qmi-wwan
```

**Donanım:**
- Qualcomm modem
- QMI interface desteği
- `/dev/cdc-wdm0` device erişimi

---

## 3. HTTP Backend (cURL)

### Kullanım

```bash
export LPAC_HTTP=curl
export LPAC_HTTP_DEBUG=1  # Debug için (opsiyonel)
```

### Gereksinimler
- `libcurl` kütüphanesi kurulu olmalı

---

## Genel Environment Variables

| Variable | Açıklama | Default Değer |
|----------|----------|---------------|
| `LPAC_APDU_DEBUG` | APDU debug çıktısı | `false` |
| `LPAC_HTTP_DEBUG` | HTTP debug çıktısı | `false` |
| `LPAC_CUSTOM_ES10X_MSS` | Maximum segment size | `120` (min: 6, max: 255) |
| `LPAC_CUSTOM_ISD_R_AID` | ISD-R AID (hex string) | `A0000005591010FFFFFFFF8900000100` |

---

## Varsayılan Davranış

> **ÖNEMLİ:** lpac varsayılan olarak sadece `pcsc` ve `stdio` backend'lerini dener!

PCSC aktif olmadığı için, **mutlaka** `LPAC_APDU` environment variable'ını ayarlamalısınız:

```bash
# Doğru kullanım
LPAC_APDU=uqmi lpac profile list

# Yanlış - çalışmaz
lpac profile list  # pcsc bulamaz, hata verir
```

---

## OpenWrt İçin Tam Konfigürasyon Örneği

### /etc/profile.d/lpac.sh Oluştur

```bash
cat > /etc/profile.d/lpac.sh << 'EOF'
#!/bin/sh
# lpac environment variables

# APDU Backend - UQMI
export LPAC_APDU=uqmi
export LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0
export LPAC_APDU_QMI_UIM_SLOT=1

# HTTP Backend - cURL
export LPAC_HTTP=curl

# Debug (gerekirse aç)
# export LPAC_APDU_DEBUG=1
# export LPAC_HTTP_DEBUG=1
EOF

chmod +x /etc/profile.d/lpac.sh
source /etc/profile.d/lpac.sh
```

### Kullanım

```bash
# Profilleri listele
lpac profile list

# Profil indir (activation code ile)
lpac profile download -a LPA:1$smdp.example.com$ACTIVATION_CODE

# Profil aktif et
lpac profile enable 1

# Profil devre dışı bırak
lpac profile disable 1

# Chip info
lpac chip info
```

---

## AT vs UQMI Karşılaştırması

| Özellik | AT Backend | UQMI Backend |
|---------|-----------|--------------|
| **Güvenilirlik** | ⚠️ Düşük (timeout sorunları) | ✅ Yüksek |
| **QMI Çakışma** | ⚠️ Var | ✅ Yok |
| **Timeout** | ❌ 300ms (yetersiz) | ✅ Yeterli |
| **OpenWrt Desteği** | ⚠️ Sınırlı | ✅ Tam destek |
| **Kullanım Amacı** | Demo/Test | Production |
| **Gerekli Paket** | - | `uqmi` |
| **Erişim** | Serial port | QMI device |

**Sonuç:** OpenWrt için **UQMI backend** önerilir.

---

## Sorun Giderme

### 1. "No APDU backend available" Hatası

**Sebep:** `LPAC_APDU` ayarlanmamış

**Çözüm:**
```bash
export LPAC_APDU=uqmi
```

### 2. "uqmi: command not found" Hatası

**Sebep:** uqmi paketi kurulu değil

**Çözüm:**
```bash
opkg update
opkg install uqmi
```

### 3. "/dev/cdc-wdm0: No such device" Hatası

**Sebep:** QMI device yok veya farklı isimde

**Çözüm:**
```bash
# QMI device'ları bul
ls -la /dev/cdc-wdm*

# Doğru device'ı ayarla
export LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm1  # örnek
```

### 4. Serial Port Permission Denied (AT Backend)

**Sebep:** Kullanıcı serial port grubunda değil

**Çözüm:**
```bash
# Kullanıcıyı gruba ekle
sudo usermod -a -G dialout $USER

# Yeniden giriş yap
newgrp dialout
```

### 5. Debug Çıktısı Almak

```bash
# APDU debug
export LPAC_APDU_DEBUG=1
export LPAC_APDU_UQMI_DEBUG=1

# HTTP debug
export LPAC_HTTP_DEBUG=1

# Tüm debug
export LPAC_APDU_DEBUG=1
export LPAC_HTTP_DEBUG=1
export LPAC_APDU_UQMI_DEBUG=1

lpac profile list
```

---

## Referanslar

- [AT Backend Dokümantasyonu](lpac/docs/backends/at.md)
- [QMI Backend Dokümantasyonu](lpac/docs/backends/qmi.md)
- [Environment Variables](lpac/docs/ENVVARS.md)
- [ETSI TS 127 007 Spesifikasyonu](https://www.etsi.org/deliver/etsi_ts/127000_127099/127007/15.02.00_60/ts_127007v150200p.pdf)

---

## Güncellenme Tarihi

Son güncelleme: 2025-10-24
