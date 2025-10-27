# Quectel EP06-E eSIM AT Komutları Detaylı Kılavuz

**Tarih:** 2025-10-26
**Modül:** Quectel EP06-E (EP06/EG06/EM06 Serisi)
**Kaynak:** EC25 Series & EG21-G eSIM AT Commands Manual, Quectel Forums, 1oT Blog

---

## İçindekiler

1. [Genel Bakış](#genel-bakış)
2. [Kurulum Komutları](#kurulum-komutları)
3. [Profil Yönetimi Komutları](#profil-yönetimi-komutları)
4. [Ağ ve Bağlantı Komutları](#ağ-ve-bağlantı-komutları)
5. [Kullanım Örnekleri](#kullanım-örnekleri)

---

## Genel Bakış

Quectel EP06-E modülü, eSIM (eUICC - embedded Universal Integrated Circuit Card) desteği sunar. Bu dokümantasyon, eSIM profil yönetimi için kullanılan AT komutlarını detaylı olarak açıklar.

### Desteklenen Modüller

- EP06 Serisi
- EG06 Serisi (EG06-E dahil)
- EM06 Serisi
- EC25 Serisi
- EG21-G Serisi
- EG25-G Serisi

### Ön Gereksinimler

- eSIM destekleyen firmware sürümü
- eUICC (gömülü SIM) donanımı
- SM-DP+ (Subscription Manager Data Preparation) sunucu erişimi
- Geçerli aktivasyon kodu (activation code)

---

## Kurulum Komutları

### 1. APN (Access Point Name) Yapılandırması

**Komut:**

```
AT+CGDCONT=<context_id>,"<pdp_type>","<apn>"
```

**Parametreler:**

- `context_id`: PDP context kimliği (genellikle 1-2 arası)
- `pdp_type`: Protokol tipi (IP, IPV6, IPV4V6)
- `apn`: Operatör tarafından sağlanan APN

**Örnek:**

```
AT+CGDCONT=1,"IP","terminal.apn"
```

**Yanıt:**

```
OK
```

---

### 2. BIP (Bearer Independent Protocol) Etkinleştirme

**Komut:**

```
AT+QCFG="bip/auth",<mode>
```

**Parametreler:**

- `mode`: 1 (etkinleştir), 0 (devre dışı bırak)

**Örnek:**

```
AT+QCFG="bip/auth",1
```

**Yanıt:**

```
OK
```

**Açıklama:** BIP, eSIM profil indirme işlemleri için gerekli data taşıyıcısıdır.

---

### 3. PDP Context Aktivasyonu

**Komut:**

```
AT+CGACT=1
```

**Yanıt:**

```
OK
```

**Açıklama:** Packet Data Protocol context'ini aktive eder.

---

## Profil Yönetimi Komutları

### AT+QESIM - Ana eSIM Komutu

Bu komut, tüm eSIM profil yönetimi işlemlerini gerçekleştirir.

---

### 1. eUICC ID (EID) Sorgulama

**Komut:**

```
AT+QESIM="eid"
```

**Yanıt:**

```
+QESIM: "eid","<EID>"
OK
```

**Açıklama:** eUICC'nin benzersiz tanımlayıcısını (32 haneli numara) döndürür.

**Örnek Yanıt:**

```
+QESIM: "eid","89049032003451234567890123456789"
OK
```

---

### 2. Profil Listeleme

**Komut:**

```
AT+QESIM="list"
```

**Yanıt:**

```
+QESIM: "list",<profile_count>
+QESIM: "list",<index>,<iccid>,<state>,<nickname>,<provider>
...
OK
```

**Parametreler:**

- `profile_count`: Toplam profil sayısı
- `index`: Profil indeksi (0'dan başlar)
- `iccid`: Integrated Circuit Card Identifier (19-20 hane)
- `state`: Profil durumu
  - 0: Disabled (Devre dışı)
  - 1: Enabled (Aktif)
- `nickname`: Profil takma adı
- `provider`: Servis sağlayıcı adı

**Örnek Yanıt:**

```
+QESIM: "list",2
+QESIM: "list",0,"8901234567890123456",1,"My Profile","Operator A"
+QESIM: "list",1,"8909876543210987654",0,"Test Profile","Operator B"
OK
```

---

### 3. Profil İndirme (OTA)

**Komut:**

```
AT+QESIM="ota","<activation_code>"[,"<confirmation_code>"]
```

**Parametreler:**

- `activation_code`: SM-DP+ sunucudan alınan aktivasyon kodu
  - Format: `LPA:1$<smdp_address>$<matching_id>`
  - Örnek: `LPA:1$smdp.example.com$ABC123XYZ`
- `confirmation_code`: (Opsiyonel) Doğrulama kodu

**Yanıt (Başarılı):**

```
+QESIM: "ota",0
OK
```

**Yanıt (Hata):**

```
+QESIM: "ota",<error_code>
ERROR
```

**Hata Kodları:**

- `1`: Genel hata
- `2`: SM-DP+ sunucuya bağlanılamadı
- `3`: Aktivasyon kodu geçersiz
- `4`: Profil indirilemedi
- `5`: eUICC belleği dolu

**Unsolicited Result Code (URC):**
Profil indirme işlemi tamamlandığında modül şu mesajı gönderir:

```
+QESIM: "download",<result>
```

- `result`: 0 (başarılı), 1 (başarısız)

**Örnek:**

```
AT+QESIM="ota","LPA:1$smdp.example.com$ABC123"
+QESIM: "ota",0
OK

// İşlem devam ederken (asenkron)...
+QESIM: "download",0  // Başarılı indirme bildirimi
```

---

### 4. Profil İndirme (Download)

**Komut:**

```
AT+QESIM="download"
```

**Açıklama:** Profil indirme işlemini başlatır. `ota` komutundan farklı olarak, bu komut aktivasyon kodunu daha önce `add_profile` ile eklenmişse kullanılır.

**Yanıt:**

```
+QESIM: "download",<ret>
OK
```

---

### 5. Profil Ekleme (Host Aracılığıyla)

**Komut:**

```
AT+QESIM="add_profile","<activation_code>"[,"<confirmation_code>"]
```

**Açıklama:** Host uygulaması aracılığıyla profil ekler, ancak henüz indirmez.

**Örnek:**

```
AT+QESIM="add_profile","LPA:1$smdp.server.com$MATCH123","1234"
OK
```

---

### 6. Profil Etkinleştirme

**Komut:**

```
AT+QESIM="enable","<iccid>"
```

**Parametreler:**

- `iccid`: Etkinleştirilecek profilin ICCID numarası

**Yanıt:**

```
+QESIM: "enable",<result>
OK
```

- `result`: 0 (başarılı), 1 (başarısız)

**Örnek:**

```
AT+QESIM="enable","8901234567890123456"
+QESIM: "enable",0
OK
```

**Not:** Bir profil etkinleştirildiğinde, önceden aktif olan profil otomatik olarak devre dışı kalır (aynı anda sadece bir profil aktif olabilir).

---

### 7. Profil Devre Dışı Bırakma

**Komut:**

```
AT+QESIM="disable","<iccid>"
```

**Parametreler:**

- `iccid`: Devre dışı bırakılacak profilin ICCID numarası

**Yanıt:**

```
+QESIM: "disable",<result>
OK
```

**Örnek:**

```
AT+QESIM="disable","8901234567890123456"
+QESIM: "disable",0
OK
```

---

### 8. Profil Silme

**Komut:**

```
AT+QESIM="delete","<iccid>"
```

**Parametreler:**

- `iccid`: Silinecek profilin ICCID numarası

**Yanıt:**

```
+QESIM: "delete",<result>
OK
```

**Örnek:**

```
AT+QESIM="delete","8901234567890123456"
+QESIM: "delete",0
OK
```

**Uyarı:** Bu işlem geri alınamaz. Profil kalıcı olarak silinir ve tekrar indirmek gerekebilir.

---

### 9. Profil Takma Adı Değiştirme

**Komut:**

```
AT+QESIM="nickname","<iccid>","<new_nickname>"
```

**Parametreler:**

- `iccid`: Profilin ICCID numarası
- `new_nickname`: Yeni takma ad (maksimum 64 karakter)

**Yanıt:**

```
+QESIM: "nickname",<result>
OK
```

**Örnek:**

```
AT+QESIM="nickname","8901234567890123456","My Work SIM"
+QESIM: "nickname",0
OK
```

---

### 10. SM-DP+ Mesaj İletimi

**Komut:**

```
AT+QESIM="trans","<message>"
```

**Açıklama:** Profil indirme ve yükleme işlemi sırasında SM-DP+ mesajlarını modüle iletir. Bu komut genellikle özel LPA uygulamaları tarafından kullanılır.

**Örnek:**

```
AT+QESIM="trans","BF2B81..."  // Base64 encoded mesaj
```

---

## Ağ ve Bağlantı Komutları

### 1. Sinyal Kalitesi Sorgulama

**Komut:**

```
AT+CSQ
```

**Yanıt:**

```
+CSQ: <rssi>,<ber>
OK
```

**Parametreler:**

- `rssi`: Received Signal Strength Indicator (0-31, 99=bilinmiyor)
  - 0-9: Zayıf sinyal
  - 10-14: Orta sinyal
  - 15-19: İyi sinyal
  - 20-31: Mükemmel sinyal
- `ber`: Bit Error Rate (0-7, 99=bilinmiyor)

**Örnek:**

```
AT+CSQ
+CSQ: 23,0
OK
```

**dBm Hesaplama:**

```
dBm = -113 + (2 * rssi)
Örnek: rssi=23 → -113 + 46 = -67 dBm
```

---

### 2. GPRS Ağ Bağlantısı

**Komut:**

```
AT+CGATT=<state>
```

**Parametreler:**

- `state`: 1 (bağlan), 0 (bağlantıyı kes)

**Örnek:**

```
AT+CGATT=1
OK
```

---

### 3. IP Adresi Sorgulama

**Komut:**

```
AT+CGPADDR[=<context_id>]
```

**Yanıt:**

```
+CGPADDR: <context_id>,"<ip_address>"
OK
```

**Örnek:**

```
AT+CGPADDR=1
+CGPADDR: 1,"10.123.45.67"
OK
```

---

### 4. Ağ Kayıt Durumu

**Komut (Sorgulama):**

```
AT+CGREG?
```

**Yanıt:**

```
+CGREG: <n>,<stat>[,<lac>,<ci>,<AcT>]
OK
```

**Parametreler:**

- `n`: Unsolicited result code modu (0,1,2)
- `stat`: Kayıt durumu
  - 0: Kayıtlı değil, arama yapmıyor
  - 1: Kayıtlı, ev ağı
  - 2: Kayıtlı değil, arama yapıyor
  - 3: Kayıt reddedildi
  - 4: Bilinmiyor
  - 5: Kayıtlı, roaming
- `lac`: Location Area Code (hex)
- `ci`: Cell ID (hex)
- `AcT`: Access Technology (0=GSM, 2=UTRAN, 3=GSM/EDGE, 4=UTRAN/HSDPA, 5=UTRAN/HSUPA, 6=UTRAN/HSPA, 7=E-UTRAN)

**Örnek:**

```
AT+CGREG?
+CGREG: 0,1,"1A2B","01C3D4E5",7
OK
```

---

### 5. Operatör Seçimi

**Otomatik Mod:**

```
AT+COPS=0
OK
```

**Manuel Mod:**

```
AT+COPS=1,2,"<operator_code>"
```

**Operatör Listesi:**

```
AT+COPS=?
```

**Örnek:**

```
AT+COPS=1,2,"26201"  // Almanya - T-Mobile
OK
```

---

## Kullanım Örnekleri

### Senaryo 1: Yeni eSIM Profil İndirme ve Aktivasyon

```
// 1. BIP'i etkinleştir
AT+QCFG="bip/auth",1
OK

// 2. APN'yi yapılandır
AT+CGDCONT=1,"IP","internet.apn"
OK

// 3. PDP context'i aktive et
AT+CGACT=1
OK

// 4. eUICC ID'yi kontrol et
AT+QESIM="eid"
+QESIM: "eid","89049032003451234567890123456789"
OK

// 5. Profil indir (aktivasyon kodu ile)
AT+QESIM="ota","LPA:1$smdp.example.com$MATCH123","1234"
+QESIM: "ota",0
OK

// İndirme tamamlanınca URC gelir:
+QESIM: "download",0

// 6. İndirilen profilleri listele
AT+QESIM="list"
+QESIM: "list",1
+QESIM: "list",0,"8901234567890123456",0,"New Profile","Operator A"
OK

// 7. Profili etkinleştir
AT+QESIM="enable","8901234567890123456"
+QESIM: "enable",0
OK

// 8. Ağ kaydını kontrol et
AT+CGREG?
+CGREG: 0,1,"1A2B","01C3D4E5",7
OK

// 9. Sinyal kalitesini kontrol et
AT+CSQ
+CSQ: 23,0
OK
```

---

### Senaryo 2: Profiller Arası Geçiş

```
// 1. Mevcut profilleri listele
AT+QESIM="list"
+QESIM: "list",2
+QESIM: "list",0,"8901234567890123456",1,"Work Profile","Operator A"
+QESIM: "list",1,"8909876543210987654",0,"Personal Profile","Operator B"
OK

// 2. Aktif profili devre dışı bırak
AT+QESIM="disable","8901234567890123456"
+QESIM: "disable",0
OK

// 3. İkinci profili etkinleştir
AT+QESIM="enable","8909876543210987654"
+QESIM: "enable",0
OK

// 4. Durum kontrolü
AT+QESIM="list"
+QESIM: "list",2
+QESIM: "list",0,"8901234567890123456",0,"Work Profile","Operator A"
+QESIM: "list",1,"8909876543210987654",1,"Personal Profile","Operator B"
OK
```

---

### Senaryo 3: Profil Silme

```
// 1. Profil listesini göster
AT+QESIM="list"
+QESIM: "list",2
+QESIM: "list",0,"8901234567890123456",0,"Old Profile","Operator A"
+QESIM: "list",1,"8909876543210987654",1,"Active Profile","Operator B"
OK

// 2. İlk profili sil (devre dışı olmalı)
AT+QESIM="delete","8901234567890123456"
+QESIM: "delete",0
OK

// 3. Silme işlemini doğrula
AT+QESIM="list"
+QESIM: "list",1
+QESIM: "list",0,"8909876543210987654",1,"Active Profile","Operator B"
OK
```

---

### Senaryo 4: Profil Takma Adı Değiştirme

```
// 1. Mevcut profil bilgilerini görüntüle
AT+QESIM="list"
+QESIM: "list",1
+QESIM: "list",0,"8901234567890123456",1,"Profile_12345","Operator A"
OK

// 2. Takma adı değiştir
AT+QESIM="nickname","8901234567890123456","My Main SIM"
+QESIM: "nickname",0
OK

// 3. Değişikliği kontrol et
AT+QESIM="list"
+QESIM: "list",1
+QESIM: "list",0,"8901234567890123456",1,"My Main SIM","Operator A"
OK
```

---

## Önemli Notlar ve Kısıtlamalar

### Genel Kısıtlamalar

1. **Tek Aktif Profil:** Aynı anda sadece bir eSIM profili aktif olabilir
2. **Profil Kapasitesi:** eUICC bellek kapasitesine bağlı olarak sınırlı sayıda profil saklanabilir (genellikle 2-5 profil)
3. **Ağ Bağlantısı:** Profil indirme için aktif data bağlantısı gereklidir
4. **Firmware Desteği:** eSIM özellikleri için uygun firmware sürümü gereklidir

### Firmware Uyumluluğu

- EP06-E için eSIM destekli firmware sürümünü kontrol edin
- Bazı eski firmware sürümleri AT+QESIM komutlarını desteklemeyebilir
- Firmware güncelleme için Quectel destek ekibiyle iletişime geçin

### Güvenlik Önlemleri

- Aktivasyon kodlarını güvenli saklayın
- SM-DP+ sunucu adreslerinin doğruluğunu kontrol edin
- Confirmation code kullanımında dikkatli olun

### Hata Ayıklama

- `AT+CMEE=2` komutu ile detaylı hata mesajlarını aktifleştirin
- Profil indirme hataları için ağ bağlantısını ve sinyal kalitesini kontrol edin
- BIP ayarlarının doğru yapılandırıldığından emin olun

---

## Referanslar

1. **Quectel EC25 Series & EG21-G eSIM AT Commands Manual** (Version 1.0.0, 2022-09-30)
2. **Quectel EP06&EG06&EM06 AT Commands Manual** (Version 1.0)
3. **1oT Blog:** AT commands 2.0 – Set Quectel EC25-E up for eSIM
4. **Quectel Forums:** eSIM AT Command Set discussions
5. **GSMA RSP Specification:** Remote SIM Provisioning Architecture

---

## Sürüm Geçmişi

| Tarih      | Versiyon | Açıklama                                    |
|------------|----------|---------------------------------------------|
| 2025-10-26 | 1.0      | İlk dokümantasyon - Detaylı komut listesi  |

---

## İletişim ve Destek

**Quectel Wireless Solutions**

- Website: <https://www.quectel.com>
- Forum: <https://forums.quectel.com>
- Teknik Destek: <support@quectel.com>

**Bu Dokümantasyon Hakkında**

- Oluşturan: Kerem Gök
- GitHub: <https://github.com/KilimcininKorOglu>

---

**DİKKAT:** Bu dokümantasyon, çeşitli kaynaklardan derlenen bilgilere dayanmaktadır. EP06-E modülünüzün spesifik özelliklerini ve kısıtlamalarını kontrol etmek için resmi Quectel dokümantasyonuna başvurun.
