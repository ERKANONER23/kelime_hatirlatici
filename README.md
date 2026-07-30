# 🇬🇧 🇹🇷 Windows Kelime Hatırlatıcı (Word Reminder)

Flutter ile geliştirilmiş, Windows işletim sisteminde arka planda çalışarak kullanıcının belirlediği saniye aralıklarıyla İngilizce-Türkçe kelime hatırlatması yapan yerel bir masaüstü uygulamasıdır. 

---

## ✨ Özellikler

* **Yerel Masaüstü Bildirimleri:** Uygulama simge durumuna küçültülse bile Windows'un yerel bildirim sistemini (Toast Notifications) kullanarak sağ alt köşede **büyük ve kalın fontlarla** bildirim gönderir.
* **Dinamik Süre Ayarı:** Kullanıcı arayüz üzerinden bildirimlerin kaç saniyede bir geleceğini canlı olarak değiştirebilir. Sayaç kendini arka planda otomatik günceller.
* **Kalıcı .txt Depolama:** Eklenen tüm kelimeler Windows Belgeler klasöründe `kelime_hatirlatici.txt` olarak saklanır. Uygulama kapatılsa dahi verileriniz kaybolmaz.
* **Kolay Kelime Yönetimi:** Arayüz üzerinden yeni İngilizce/Türkçe kelime çiftleri eklenebilir veya mevcut kelimeler tek tıkla silinebilir.

---

## 🚀 Kurulum ve Çalıştırma (Geliştiriciler İçin)

Projeyi kendi bilgisayarınızda derlemek ve çalıştırmak için aşağıdaki adımları takip edin:

### 1. Gereksinimler
* Bilgisayarınızda [Flutter SDK](https://flutter.dev) kurulu olmalıdır.
* Windows üzerinde derleme yapabilmek için **C++ ile Masaüstü Geliştirme** araç paketi yüklü bir [Visual Studio](https://microsoft.com) kurulu olmalıdır.
* Windows ayarlarından **Geliştirici Modu (Developer Mode)** açık olmalıdır.

### 2. Projeyi Klonlayın ve Bağımlılıkları Kurun
```bash
# Depoyu bilgisayarınıza indirin
git clone https://github.com

# Proje dizinine girin
cd kelime_hatirlatici

# Gerekli Flutter paketlerini indirin
flutter pub get
```

### 3. Uygulamayı Başlatın
```bash
flutter run -d windows
```

### 4. Sürüm (Release) Sürümünü Derleme
Son kullanıcıya dağıtılacak optimize edilmiş `.exe` çıktısını almak için:
```bash
flutter build windows --release
```

---

## 📦 Hazır Sürümü İndir (Son Kullanıcılar İçin)

Kodlarla uğraşmadan uygulamayı doğrudan Windows bilgisayarınızda çalıştırmak istiyorsanız, projenin sağ tarafında bulunan **[Releases](https://github.com)** bölümünden en güncel `ZIP` paketini indirebilirsiniz. 

*İndirdiğiniz ZIP dosyasını bir klasöre çıkartıp içerisindeki `.exe` dosyasına çift tıklamanız yeterlidir.*

---

## 🛠️ Kullanılan Paketler (Dependencies)

* [local_notifier](https://pub.dev) - Windows yerel bildirim yönetimi için.
* [path_provider](https://pub.dev) - Kelimelerin `.txt` dosyasına kalıcı yazılması için.

---
*Bu proje açık kaynaklı bir kelime ezberleme asistanıdır.*
