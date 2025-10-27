# LPAC Kullanım Kılavuzu

**Versiyon:** 2.3.0  
**Platform:** OpenWrt / GL-XE300  
**Modem:** Quectel EP06-E

---

## Kurulum

### GL-XE300 Router İçin

```bash
# Router'a yükle
scp lpac_*.ipk root@192.168.8.1:/tmp/
ssh root@192.168.8.1
opkg install /tmp/lpac_*.ipk
```

### Ortam Değişkenlerini Ayarla

```bash
export LPAC_APDU=at
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2
```

---

## Temel Kullanım

### Komut Formatı

```
lpac <komut> <alt-komut> [parametreler]
```

### JSON Çıktı Formatı

Tüm komutlar JSON döndürür:

```json
{
  "type": "lpa",
  "payload": {
    "code": 0,
    "message": "success",
    "data": { /* sonuç */ }
  }
}
```

- `code: 0` = Başarılı
- `code: ≠ 0` = Hata

---

## Komutlar

### 1. Chip Bilgisi

#### eUICC Bilgisi Gör

```bash
lpac chip info
```

Döndürür: EID, SM-DP+ sunucu, SM-DS sunucu, chip özellikleri

#### Varsayılan SM-DP+ Değiştir

```bash
lpac chip defaultsmdp <sunucu-adresi>
```

Örnek:
```bash
lpac chip defaultsmdp rsp.truphone.com
```

#### eUICC'yi Sıfırla (⚠️ TEHLİKELİ)

```bash
lpac chip purge
```

**UYARI:** TÜM profilleri kalıcı olarak siler!

---

### 2. Profil Yönetimi

#### Profilleri Listele

```bash
lpac profile list
```

#### Yeni Profil İndir

**Aktivasyon Kodu ile:**

```bash
lpac profile download -s <sm-dp-sunucu> -m <matching-id>
```

Örnek:
```bash
lpac profile download -s rsp.truphone.com -m "QR-G-5C-1LS-1W1Z9P7"
```

**QR Kod String'i ile:**

```bash
lpac profile download -a 'LPA:1$rsp.truphone.com$QR-G-5C-1LS-1W1Z9P7'
```

**Confirmation Code ile:**

```bash
lpac profile download -s rsp.truphone.com -m "MATCHING-ID" -c "1234"
```

**IMEI ile:**

```bash
lpac profile download -s rsp.truphone.com -m "MATCHING-ID" -i "123456789012345"
```

#### Profil Aktif Et

```bash
lpac profile enable <ICCID>
```

Örnek:
```bash
lpac profile enable 8901234567890123456
```

#### Profil Pasif Et

```bash
lpac profile disable <ICCID>
```

#### Profil Sil

```bash
lpac profile delete <ICCID>
```

**UYARI:** Onay sormuyor! Bildirim oluşturur, gönderilmeli.

#### Profil İsmi Ver

```bash
lpac profile nickname <ICCID> "İsim"
```

Örnek:
```bash
lpac profile nickname 8901234567890123456 "Vodafone İş"
```

#### Profil Keşfet (SM-DS)

```bash
lpac profile discovery
```

---

### 3. Bildirim Yönetimi

#### Bildirimleri Listele

```bash
lpac notification list
```

#### Bildirim Gönder

```bash
lpac notification process <seq-number>
```

**Tümünü İşle:**

```bash
lpac notification process -a
```

**İşleyip Otomatik Sil:**

```bash
lpac notification process <seq-number> -r
lpac notification process -a -r
```

#### Bildirimi Sil

```bash
lpac notification remove <seq-number>
```

**Tümünü Sil:**

```bash
lpac notification remove -a
```

---

### 4. Driver Bilgisi

#### Mevcut Driver'ları Listele

```bash
lpac driver list
```

#### APDU Cihazları Listele

```bash
lpac driver apdu list
```

AT driver için seri portları gösterir.

---

## Ortam Değişkenleri

### APDU Backend

- `LPAC_APDU`: Backend tipi (`at`, `at_csim`, `pcsc`)
- `LPAC_APDU_AT_DEVICE`: Seri port (varsayılan: `/dev/ttyUSB0`)
- `LPAC_APDU_AT_DEBUG`: Debug modu (`0`/`1`)

### HTTP Backend

- `LPAC_HTTP`: Backend tipi (`curl`)

---

## Kullanım Senaryoları

### İlk Kurulum

```bash
# 1. eUICC bilgisi kontrol et
lpac chip info

# 2. Mevcut profilleri keşfet (SM-DS kayıtlı ise)
lpac profile discovery

# 3. Profil indir
lpac profile download -a 'LPA:1$smdp.server.com$ACTIVATION-CODE'

# 4. Profilleri listele
lpac profile list

# 5. Profili aktif et
lpac profile enable 8901234567890123456

# 6. Bildirimleri işle
lpac notification list
lpac notification process -a -r
```

### Profiller Arası Geçiş

```bash
# Mevcut profili pasif et
lpac profile disable 8901234567890123456

# Hedef profili aktif et
lpac profile enable 8901234567890123457

# Bildirimleri işle
lpac notification process -a -r
```

### İstenmeyen Profili Sil

```bash
# Profili sil
lpac profile delete 8901234567890123456

# Silme bildirimini gönder
lpac notification list
lpac notification process <seq-number> -r
```

---

## Sorun Giderme

### AT Driver Sorunları

**Sorun:** "Seri port açılamıyor"

```bash
# Cihazın olup olmadığını kontrol et
ls -l /dev/ttyUSB*

# İzinleri kontrol et
sudo chmod 666 /dev/ttyUSB2

# Doğru portu ayarla
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2
```

**Sorun:** "Timeout / Yanıt yok"

```bash
# Debug modu aç
export LPAC_APDU_AT_DEBUG=1
lpac chip info

# Farklı AT backend dene
export LPAC_APDU=at_csim  # 'at' yerine
```

**Sorun:** "İşlem başarısız"

- Bazı işlemler yetersiz yanıt süresi nedeniyle başarısız olabilir (300ms limit)
- Birkaç kez deneyin
- Enable/disable için AID kullanın (ICCID yerine)
- RefreshFlag'i değiştirin (0 veya 1)

### Profil İndirme Sorunları

**Sorun:** "Geçersiz aktivasyon kodu"

- Aktivasyon kodu formatını kontrol edin
- SM-DP+ sunucu adresini doğrulayın
- İnternet bağlantısını kontrol edin

**Sorun:** "Yetersiz bellek"

```bash
# eUICC belleğini kontrol et
lpac chip info
# "freeNonVolatileMemory" değerine bakın

# Kullanılmayan profilleri silin
lpac profile delete <ICCID>
```

---

## GL-XE300 İçin Özel Notlar

### Quectel EP06-E Modem

- **AT Port:** Genellikle `/dev/ttyUSB2`
- **Modem Port:** `/dev/ttyUSB3`
- **AT Driver Kullan:** `LPAC_APDU=at`

### lpac Kullanmadan Önce

```bash
# ModemManager çalışıyorsa durdur
/etc/init.d/modemmanager stop
```

### Kalıcı Yapılandırma

`/etc/profile.d/lpac.sh` oluştur:

```bash
#!/bin/sh
export LPAC_APDU=at
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2
```

Sonra:

```bash
chmod +x /etc/profile.d/lpac.sh
source /etc/profile.d/lpac.sh
```

---

## Önemli Notlar

### AT Driver Kısıtlamaları

⚠️ AT driver **deprecated** ve gelecekte kaldırılabilir.

- Maksimum yanıt süresi: 300ms (genellikle yetersiz)
- Bazı işlemler rastgele başarısız olabilir
- Üretim kullanımı için uygun değil
- Sadece test/demo için kullanın

### Bildirimler

- Profil işlemlerinden sonra her zaman bildirimleri işleyin
- İşledikten sonra otomatik silmek için `-r` flag kullanın
- Bildirim listesini düzenli kontrol edin

### Profil Durumları

- Bir anda sadece BİR profil AKTİF olabilir
- Diğer profiller PASİF olmalı
- Silinen profiller kurtarılamaz (tekrar indirilmedikçe)

---

## Hızlı Referans

| Görev | Komut |
|------|-------|
| Profil listele | `lpac profile list` |
| Profil indir | `lpac profile download -a 'LPA:1$server$code'` |
| Profil aktif et | `lpac profile enable <ICCID>` |
| Profil pasif et | `lpac profile disable <ICCID>` |
| Profil sil | `lpac profile delete <ICCID>` |
| Profil isimlendır | `lpac profile nickname <ICCID> "İsim"` |
| Bildirimleri listele | `lpac notification list` |
| Tüm bildirimleri işle | `lpac notification process -a -r` |
| eUICC bilgisi | `lpac chip info` |
| Profil keşfet | `lpac profile discovery` |

---

## Kaynaklar

- **Resmi Repo:** https://github.com/estkme-group/lpac
- **Dokümantasyon:** https://github.com/estkme-group/lpac/tree/main/docs
- **SGP.22 Spec:** https://www.gsma.com/esim/

---

**Lisans:** AGPL-3.0  
**Copyright:** © 2023-2025 ESTKME TECHNOLOGY LIMITED
