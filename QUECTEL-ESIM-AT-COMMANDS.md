# Quectel eSIM AT Command Set

> Kaynak: https://forums.quectel.com/t/esim-at-command-set/13313
>
> Tarih: Şubat 2022 - Mayıs 2023

## Genel Bakış

Bu doküman Quectel modüllerde (özellikle EM160R) eSIM desteği ve AT komutları hakkında topluluk forumunda yapılan tartışmaları içermektedir.

---

## Orijinal Soru (Tantalum, 20 Şubat 2022)

### Konu: Quectel EM160R Modülünde eSIM Desteği

**Firmware Versiyonu:** EM160RGLAUR02A09M4G

### Üç Ana Soru:

#### 1. eSIM Komut Desteği

**Soru:** EM160R firmware'inde eSIM komutları destekleniyor mu?

**Cevap (Kerr.Yang-Q):** Evet, komutlar destekleniyor.

---

#### 2. eSIM AT Komutları Dokümantasyonu

**Soru:** Aşağıdaki komutlar için detaylı dokümantasyon bulunamıyor:

- `AT+QESIM="add_profile"`
- `AT+QESIM="def_svr_addr"`
- `AT+QESIM="lpa_enable"`

**QR Kod Örneği:**
```
LPA:1$dptest.linksfield.net$C0C3D-2BH7J-0VMF8-RY2VS
```

**QR Kod Yapısı:**
- `LPA:1` - Protokol
- `dptest.linksfield.net` - Registration server (SM-DP+ sunucusu)
- `C0C3D-2BH7J-0VMF8-RY2VS` - Activation key (aktivasyon kodu)

**Cevap (Kerr.Yang-Q):**
- Dokümantasyon mevcut değil
- `AT+QESIM=?` komutu ile parametre aralıklarını görüntüleyebilirsiniz

**Ek Bilgi (lyman-Q, 6 Mayıs 2023):**
- AT+QSIM komut dokümantasyonu ekran görüntüleri ile paylaşıldı
- Detaylı parametre kullanımı ve yönergeler eklendi

**Resmi Dokümantasyon (Kerr.Yang-Q, 17 Mayıs 2023):**
- *Quectel EC25 Series & EG21-G eSIM AT Commands Manual V1.0.0* (476.7 KB PDF) yayınlandı

---

#### 3. SIM Slot Değiştirme

**Soru:** eSIM profilleri provision edildikten sonra SIM slotları arasında nasıl geçiş yapılır? `AT+QUIMSLOT` sadece fiziksel slotlarla sınırlı görünüyor.

**Cevap (Kerr.Yang-Q):**
- **Gereksinim:** `Usim_det` pini kart slot CD pinine bağlanmalı
- **Hot-swap desteği yok**
- **Geçiş için:** Yeniden başlatma veya `AT+CFUN=0/1` komutu gerekli

---

## AT Komutları

### Temel eSIM Komutları

#### 1. AT+QESIM - eSIM Yönetimi

**Kullanım:**
```
AT+QESIM=?
```

**Alt Komutlar:**

##### a) add_profile - Profil Ekleme
```
AT+QESIM="add_profile"
```
QR kod ile profil ekleme işlemi.

##### b) def_svr_addr - Varsayılan Sunucu Adresi
```
AT+QESIM="def_svr_addr"
```
SM-DP+ sunucu adresini ayarlama.

##### c) lpa_enable - LPA Etkinleştirme
```
AT+QESIM="lpa_enable"
```
Local Profile Assistant (LPA) fonksiyonunu aktif etme.

---

#### 2. AT+QUIMSLOT - SIM Slot Seçimi

**Kullanım:**
```
AT+QUIMSLOT?       # Mevcut slot bilgisi
AT+QUIMSLOT=<n>    # Slot değiştirme
```

**Parametreler:**
- `<n>`: Slot numarası (fiziksel slot)

**⚠️ Dikkat:**
- Sadece fiziksel slotlar desteklenir
- eSIM profilleri arası geçiş için `AT+CFUN=0/1` kullanılmalı

---

#### 3. AT+CFUN - Modem Fonksiyon Seviyesi

**Kullanım:**
```
AT+CFUN=0    # Minimum fonksiyon (RF kapalı)
AT+CFUN=1    # Tam fonksiyon (Normal mod)
```

**eSIM İçin Kullanım:**
- SIM profil değişikliğinden sonra uygulanmalı
- Soft reset işlevi görür

---

## QR Kod Formatı

### LPA QR Kod Yapısı

```
LPA:1$<SM-DP+ Address>$<Activation Code>
```

**Örnek:**
```
LPA:1$dptest.linksfield.net$C0C3D-2BH7J-0VMF8-RY2VS
```

**Bileşenler:**

| Bileşen | Açıklama | Örnek |
|---------|----------|-------|
| `LPA:1` | Protokol versiyonu | LPA:1 |
| SM-DP+ Address | SM-DP+ sunucu adresi | dptest.linksfield.net |
| Activation Code | Profil aktivasyon kodu | C0C3D-2BH7J-0VMF8-RY2VS |

---

## Donanım Gereksinimleri

### eSIM İçin Pin Bağlantıları

**Kritik Bağlantı:**
```
Usim_det pin --> Card Slot CD pin
```

**⚠️ Önemli Notlar:**
- Bu bağlantı **zorunlu**
- Hot-swap desteklenmez
- Slot değişikliği için restart gerekir

---

## Bilinen Sorunlar ve Sınırlamalar

### 1. Dokümantasyon

❌ **Sorunlar:**
- eSIM AT komutları için detaylı dokümantasyon eksik
- Sadece temel manual mevcut (EC25/EG21-G için)
- EM160R'e özel güncel dokümantasyon yok

✅ **Çözümler:**
- `AT+QESIM=?` ile parametre keşfi
- EC25/EG21-G manual'ı referans alınabilir
- Forum topluluğundan destek

### 2. SIM Slot Yönetimi

❌ **Sorunlar:**
- Hot-swap desteklenmiyor
- eSIM profilleri arası geçiş karmaşık
- Fiziksel slot ve eSIM profil yönetimi ayrı

✅ **Geçici Çözüm:**
- `AT+CFUN=0/1` ile soft reset
- Donanım restart

### 3. Model Desteği

**Belirsizlikler:**
- Entegre vs. harici eSIM desteği model bazlı
- Tüm modeller için unified dokümantasyon yok
- Bazı modellerde hata mesajları rapor edildi

---

## Uygulama Örnekleri

### Örnek 1: eSIM Profil Ekleme

```bash
# 1. LPA'yı etkinleştir
AT+QESIM="lpa_enable"

# 2. SM-DP+ sunucu adresini ayarla
AT+QESIM="def_svr_addr","dptest.linksfield.net"

# 3. Profil ekle (Activation code ile)
AT+QESIM="add_profile","C0C3D-2BH7J-0VMF8-RY2VS"

# 4. Modem'i yeniden başlat
AT+CFUN=0
AT+CFUN=1
```

### Örnek 2: QR Kod Parse Etme

**QR Kod:**
```
LPA:1$smdp.example.com$ABC12-DEF34-GHI56-JKL78
```

**Parse Edilmiş:**
```bash
Protocol: LPA:1
SM-DP+: smdp.example.com
ActivationCode: ABC12-DEF34-GHI56-JKL78
```

**AT Komutu:**
```bash
AT+QESIM="def_svr_addr","smdp.example.com"
AT+QESIM="add_profile","ABC12-DEF34-GHI56-JKL78"
```

---

## Referanslar

### Resmi Dokümantasyon

1. **Quectel EC25 Series & EG21-G eSIM AT Commands Manual V1.0.0**
   - Boyut: 476.7 KB
   - Yayın: 17 Mayıs 2023
   - Yayıncı: Kerr.Yang-Q

### Forum Tartışması

- **Başlık:** eSIM AT-Command Set
- **URL:** https://forums.quectel.com/t/esim-at-command-set/13313
- **Tarih Aralığı:** Şubat 2022 - Mayıs 2023
- **Katılımcılar:**
  - Tantalum (Soru sahibi)
  - Kerr.Yang-Q (Quectel resmi destek)
  - lyman-Q (Quectel destek)

### İlgili Standartlar

- **GSMA SGP.22:** RSP Technical Specification
- **GSMA SGP.21:** RSP Architecture

---

## SSS (Sıkça Sorulan Sorular)

### S1: Hangi Quectel modüller eSIM destekliyor?

**C:** Forum tartışmasında belirtilen modeller:
- EM160R (doğrulandı)
- EC25 Series (dokümantasyon mevcut)
- EG21-G (dokümantasyon mevcut)

Diğer modeller için Quectel desteğine başvurun.

### S2: eSIM profili nasıl silinir?

**C:** Forum tartışmasında belirtilmedi. AT+QESIM komutunun "delete_profile" veya benzeri bir parametresi olması muhtemeldir. `AT+QESIM=?` ile kontrol edin.

### S3: Birden fazla eSIM profili aynı anda aktif olabilir mi?

**C:** Hayır. Sadece bir profil aynı anda aktif olabilir. Profiller arası geçiş için `AT+CFUN=0/1` gerekir.

### S4: QR kod olmadan manuel profil eklenebilir mi?

**C:** Evet, QR kod içeriği parse edilerek manuel olarak komutlar gönderilebilir:
- SM-DP+ adresi: `AT+QESIM="def_svr_addr","<address>"`
- Activation code: `AT+QESIM="add_profile","<code>"`

### S5: AT backend ile lpac uyumlu mu?

**C:** lpac dokümantasyonunda AT backend "NO LONGER MAINTAINED" olarak işaretlenmiş ve timeout sorunları nedeniyle sadece demo amaçlı önerilmektedir. Production ortamlar için UQMI backend tercih edilmelidir.

---

## Karşılaştırma: AT vs UQMI

| Özellik | AT Backend | UQMI Backend |
|---------|-----------|--------------|
| **Timeout** | 300ms (yetersiz) | Yeterli |
| **Güvenilirlik** | Düşük | Yüksek |
| **QMI Çakışma** | Var | Yok |
| **Bakım Durumu** | Deprecated | Aktif |
| **Kullanım Amacı** | Demo/Test | Production |
| **OpenWrt Desteği** | Sınırlı | Tam |

**Sonuç:** Quectel modüller ile lpac kullanımında **UQMI backend** tercih edilmelidir.

---

## Güncellenme Geçmişi

| Tarih | Açıklama |
|-------|----------|
| 2025-10-24 | İlk markdown versiyonu oluşturuldu |
| 2023-05-17 | Quectel resmi eSIM AT Commands Manual yayınlandı |
| 2023-05-06 | AT+QSIM dokümantasyonu eklendi (lyman-Q) |
| 2022-02-23 | İlk resmi yanıt (Kerr.Yang-Q) |
| 2022-02-20 | Orijinal forum sorusu (Tantalum) |

---

## Yasal Uyarı

Bu doküman topluluk forumundan derlenen bilgileri içermektedir. Resmi ve güncel bilgi için Quectel'in resmi dokümantasyonuna başvurun.

**Quectel İletişim:**
- Forum: https://forums.quectel.com/
- Destek: Resmi Quectel destek kanalları

---

## Katkıda Bulunanlar

- **Tantalum:** Orijinal soru ve detaylı araştırma
- **Kerr.Yang-Q:** Quectel resmi destek
- **lyman-Q:** Quectel teknik destek ve dokümantasyon
- **lpac Topluluğu:** AT backend dokümantasyonu ve UQMI karşılaştırması
