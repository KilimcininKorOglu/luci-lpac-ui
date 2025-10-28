# LPAC AT Driver Kullanım Kılavuzu

**Platform:** OpenWrt / GL-XE300
**Modem:** Quectel EP06-E
**Driver:** AT (ETSI TS 127 007)
**lpac Versiyon:** 2.3.0

---

## AT Driver Nedir?

AT driver, lpac'ın modem ile seri port üzerinden AT komutları kullanarak iletişim kurmasını sağlar. Quectel EP06-E gibi modemler için tasarlanmıştır.

### AT Driver Türleri

lpac iki AT driver varyantı sunar:

1. **`at`** (ETSI TS 127 007 uyumlu)
   - Standart AT+CCHO, AT+CCHC, AT+CGLA komutları kullanır
   - Çoklu logical channel desteği
   - Daha yavaş ama uyumlu

2. **`at_csim`** (AT+CSIM tabanlı)
   - AT+CSIM komutu kullanır
   - Tek logical channel (default)
   - Daha hızlı ancak bazı modellerde desteklenmez

---

## Kurulum ve Yapılandırma

### 1. Ortam Değişkenlerini Ayarla

```bash
# AT driver kullan
export LPAC_APDU=at

# Seri port ayarla (EP06-E için genellikle ttyUSB2)
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2

# Debug modu (opsiyonel)
export LPAC_APDU_AT_DEBUG=1
```

### 2. Kalıcı Yapılandırma

`/etc/profile.d/lpac.sh` oluştur:

```bash
#!/bin/sh
export LPAC_APDU=at
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2
export LPAC_HTTP=curl
```

Ardından:

```bash
chmod +x /etc/profile.d/lpac.sh
source /etc/profile.d/lpac.sh
```

### 3. Seri Port İzinlerini Ayarla

```bash
# Port izinlerini kontrol et
ls -l /dev/ttyUSB*

# İzinleri düzelt
chmod 666 /dev/ttyUSB2
```

---

## Quectel EP06-E için Port Yapısı

EP06-E modemi 4 seri port açar:

```
/dev/ttyUSB0  → Diagnostic port (DM)
/dev/ttyUSB1  → GPS NMEA port
/dev/ttyUSB2  → AT command port (lpac için kullan)
/dev/ttyUSB3  → PPP modem port
```

**lpac için:** `/dev/ttyUSB2` kullanılır.

---

## AT Driver ile Temel Kullanım

### eUICC Bilgisi Görüntüle

```bash
lpac chip info
```

**Çıktı örneği:**

```json
{
  "type": "lpa",
  "payload": {
    "code": 0,
    "message": "success",
    "data": {
      "eidValue": "89049032008800000123456789012345",
      "eid": "89049032008800000123456789012345",
      "smdsAddress": "DEFAULT.SMDS.ADDRESS",
      "smdpAddress": "rsp.truphone.com"
    }
  }
}
```

### Mevcut Profilleri Listele

```bash
lpac profile list
```

### Yeni Profil İndir

**QR Kod formatı ile:**

```bash
lpac profile download -a 'LPA:1$smdp.server.com$ACTIVATION-CODE'
```

**SM-DP+ ve Matching ID ile:**

```bash
lpac profile download -s smdp.server.com -m "MATCHING-ID"
```

**Confirmation Code ile:**

```bash
lpac profile download -s smdp.server.com -m "MATCHING-ID" -c "1234"
```

### Profil Aktif/Pasif Etme

```bash
# Aktif et
lpac profile enable 8901234567890123456

# Pasif et
lpac profile disable 8901234567890123456
```

### Bildirimleri İşle

```bash
# Bildirimleri listele
lpac notification list

# Tüm bildirimleri işle ve sil
lpac notification process -a -r
```

---

## AT Driver Özellikleri ve Kısıtlamalar

### ✅ Desteklenen Özellikler

- eUICC bilgi okuma (EID, ICCID)
- Profil indirme (download)
- Profil aktif/pasif etme (enable/disable)
- Profil silme (delete)
- Profil isimlendirme (nickname)
- Bildirim yönetimi (notification)
- SM-DS keşfi (discovery)

### ⚠️ Bilinen Kısıtlamalar

1. **Yanıt Süresi:**
   - AT komutu yanıt süresi genellikle 300ms ile sınırlı
   - Uzun işlemler (download, delete) zaman aşımına uğrayabilir
   - Birkaç kez deneme gerekebilir

2. **Enable/Disable Sorunları:**
   - ICCID ile enable/disable bazen başarısız olur
   - **Çözüm:** AID (Application ID) kullanın:

     ```bash
     lpac profile enable A0000005591010FFFFFFFF8900000100
     ```

3. **RefreshFlag:**
   - Bazı durumlarda RefreshFlag değiştirme gerekir
   - lpac varsayılan değer kullanır, manuel müdahale nadiren gerekir

4. **Baud Rate:**
   - Varsayılan: 115200
   - EP06-E için uygun, değiştirmeye gerek yok

---

## Debug ve Sorun Giderme

### Debug Modunu Aktif Et

```bash
export LPAC_APDU_AT_DEBUG=1
lpac chip info
```

**Debug çıktısı gösterir:**

```
TX: AT+CCHO="A0000005591010FFFFFFFF8900000100"
RX: 1
RX: OK
TX: AT+CGLA=1,10,"8022000000"
RX: 9000
RX: OK
...
```

### Yaygın Sorunlar ve Çözümler

#### 1. "Seri Port Açılamıyor"

**Belirtiler:**

```
Failed to open device: /dev/ttyUSB2
```

**Çözümler:**

```bash
# Port varlığını kontrol et
ls -l /dev/ttyUSB*

# İzinleri düzelt
chmod 666 /dev/ttyUSB2

# Portu başka process kullanıyor mu?
lsof | grep ttyUSB2

# ModemManager'ı durdur
/etc/init.d/modemmanager stop
```

#### 2. "Device Not Responding"

**Belirtiler:**

```
Device not responding to AT commands
```

**Çözümler:**

```bash
# Portu test et
echo -e "AT\r\n" > /dev/ttyUSB2

# Modem resetle
AT+CFUN=1,1  # Modem restart

# Farklı port dene
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB3
```

#### 3. "Operation Timed Out"

**Belirtiler:**

```
Operation timed out after 300ms
```

**Çözümler:**

```bash
# İşlemi tekrar dene (2-3 kez)
lpac profile download -a '...'

# at_csim driver kullanmayı dene
export LPAC_APDU=at_csim
lpac profile download -a '...'

# İnternet bağlantısını kontrol et
ping -c 4 8.8.8.8
```

#### 4. "Enable/Disable Başarısız"

**Belirtiler:**

```
Failed to enable profile
```

**Çözümler:**

```bash
# ICCID yerine AID kullan
# Önce profilleri listele ve AID değerini al
lpac profile list

# AID ile enable et
lpac profile enable A0000005591010FFFFFFFF8900000100

# Alternatif: at_csim driver dene
export LPAC_APDU=at_csim
lpac profile enable 8901234567890123456
```

#### 5. "Missing +CSIM Support"

**Belirtiler:**

```
Device missing +CSIM support
```

**Çözüm:**

```bash
# ETSI driver kullan
export LPAC_APDU=at
lpac chip info
```

---

## AT vs AT_CSIM Karşılaştırma

| Özellik | `at` (ETSI) | `at_csim` |
|---------|-------------|-----------|
| Standart | ETSI TS 127 007 | AT+CSIM |
| Uyumluluk | Yüksek | Orta |
| Hız | Orta | Yüksek |
| Logical Channels | Çoklu | Tek |
| EP06-E Uyumluluğu | ✅ Mükemmel | ✅ İyi |
| Kararlılık | ✅ İyi | ⚠️ Orta |
| Önerilen | ✅ Evet | Sorun varsa |

**Öneri:** Varsayılan olarak `at` driver kullanın. Sorun yaşarsanız `at_csim` deneyin.

---

## İleri Düzey Kullanım

### AT Komutlarını Manuel Test Etme

```bash
# Terminal aç
screen /dev/ttyUSB2 115200

# veya
minicom -D /dev/ttyUSB2 -b 115200

# Test komutları
AT
AT+CCHO="A0000005591010FFFFFFFF8900000100"
AT+CCHC=1
AT+CGLA=1,10,"8022000000"
```

**Çıkış:** `Ctrl+A` sonra `K` (screen) veya `Ctrl+A` `X` (minicom)

### Farklı Baud Rate Kullanma

lpac varsayılan olarak 115200 kullanır. Değiştirmek için kaynak kodda `at_cmd_unix.c` dosyasını düzenleyin:

```c
// Varsayılan
cfsetospeed(&tio, B115200);
cfsetispeed(&tio, B115200);

// 9600'e değiştir
cfsetospeed(&tio, B9600);
cfsetispeed(&tio, B9600);
```

### AT Driver'ı Başka Modemlerle Kullanma

AT driver ETSI TS 127 007 standardına uygun modemlerle çalışır:

**Desteklenen modemler:**

- Quectel EP06-E (✅ Test edildi)
- Quectel RG500Q
- Quectel RM500Q
- Simcom SIM7600
- Fibocom FM150 (kısmi)

**Test etmek için:**

```bash
# Modem AT desteğini kontrol et
echo -e "AT+CCHO=?\r\n" > /dev/ttyUSB2
echo -e "AT+CGLA=?\r\n" > /dev/ttyUSB2
```

---

## Performans İpuçları

### 1. ModemManager'ı Devre Dışı Bırak

```bash
# Geçici
/etc/init.d/modemmanager stop

# Kalıcı
/etc/init.d/modemmanager disable
```

### 2. İnternet Bağlantısını Optimize Et

```bash
# DNS hızlandır
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# MTU optimize et
ifconfig wwan0 mtu 1400
```

### 3. Batch İşlemler İçin Script

```bash
#!/bin/bash
# batch-profile-download.sh

PROFILES=(
  "LPA:1$server1$code1"
  "LPA:1$server2$code2"
  "LPA:1$server3$code3"
)

for profile in "${PROFILES[@]}"; do
  echo "Downloading: $profile"
  lpac profile download -a "$profile"

  # Hata varsa 3 kez dene
  if [ $? -ne 0 ]; then
    for i in {1..3}; do
      echo "Retry $i/3..."
      sleep 2
      lpac profile download -a "$profile" && break
    done
  fi

  # Bildirimleri işle
  lpac notification process -a -r

  sleep 5
done
```

---

## AT Komut Referansı

### ETSI TS 127 007 AT Komutları

lpac tarafından kullanılan temel AT komutları:

```bash
AT                  # Modem hazır mı?
AT+CCHO="<AID>"    # Logical channel aç
AT+CCHC=<channel>  # Logical channel kapat
AT+CGLA=<ch>,<len>,"<cmd>"  # APDU gönder
AT+CSIM=<len>,"<cmd>"       # CSIM APDU gönder (at_csim)
```

**Örnek APDU komutları:**

```bash
# SELECT eSIM applet
AT+CCHO="A0000005591010FFFFFFFF8900000100"

# GET EID
AT+CGLA=1,10,"8022000000"

# GET ICCID
AT+CGLA=1,10,"80220000"
```

---

## Güvenlik ve İzinler

### Seri Port İzinleri

```bash
# Root olmadan erişim için
usermod -a -G dialout $USER

# Veya udev kuralı ekle
echo 'KERNEL=="ttyUSB*", MODE="0666"' > /etc/udev/rules.d/99-usb-serial.rules
udevadm control --reload-rules
```

### Profil Şifreleme

lpac AT driver üzerinden indirilen profiller modem tarafından şifrelenir. Ek şifreleme gerekmez.

---

## Hızlı Referans

| Görev | Komut |
|-------|-------|
| eUICC bilgisi | `lpac chip info` |
| Profil listele | `lpac profile list` |
| Profil indir | `lpac profile download -a 'LPA:...'` |
| Profil aktif et | `lpac profile enable <ICCID>` |
| Profil pasif et | `lpac profile disable <ICCID>` |
| Profil sil | `lpac profile delete <ICCID>` |
| Bildirim işle | `lpac notification process -a -r` |
| Debug aç | `export LPAC_APDU_AT_DEBUG=1` |
| Driver değiştir | `export LPAC_APDU=at_csim` |
| Port değiştir | `export LPAC_APDU_AT_DEVICE=/dev/ttyUSB3` |

---

## Alternatif Driverlar

lpac birden fazla APDU driver destekler:

```bash
# AT driver (varsayılan, önerilen)
export LPAC_APDU=at

# AT CSIM driver (daha hızlı)
export LPAC_APDU=at_csim

# PC/SC driver (akıllı kart okuyucu)
export LPAC_APDU=pcsc

# MBIM driver (MBIM modemler için)
export LPAC_APDU=mbim

# QMI driver (Quectel QMI modlar için)
# Not: lpac resmi olarak QMI desteklemiyor,
# quectel_lpad kullanın
```

---

## Sorun Raporlama

AT driver ile ilgili sorun yaşarsanız, aşağıdaki bilgileri toplayın:

```bash
# 1. Sistem bilgisi
uname -a
cat /etc/openwrt_release

# 2. lpac versiyonu
lpac --version

# 3. Modem bilgisi
cat /dev/ttyUSB2 << EOF
ATI
AT+CGMR
AT+CGSN
AT+CIMI
EOF

# 4. Debug çıktısı
export LPAC_APDU_AT_DEBUG=1
lpac chip info > debug.log 2>&1

# 5. Seri port durumu
ls -l /dev/ttyUSB*
lsof | grep ttyUSB
```

---

## Ek Kaynaklar

- **lpac Genel Kılavuz:** [lpac.md](lpac.md)
- **LuCI Web Arayüzü:** [LUCI.md](LUCI.md)
- **EP06-E AT Komutları:** [EP06-E_ESIM_AT_COMMANDS.md](EP06-E_ESIM_AT_COMMANDS.md)
- **ETSI TS 127 007 Spec:** <https://www.etsi.org/deliver/etsi_ts/127000_127099/127007/>
- **lpac GitHub:** <https://github.com/estkme-group/lpac>
- **SGP.22 Spec:** <https://www.gsma.com/esim/>

---

**Son Güncelleme:** 2025-01
**Yazar:** Kerem
**Lisans:** AGPL-3.0
