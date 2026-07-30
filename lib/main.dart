import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Sadece sayı girişine izin vermek için
import 'package:local_notifier/local_notifier.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows bildirimi için uygulamayı sisteme kaydediyoruz
  await localNotifier.setup(
    appName: 'Kelime Hatırlatıcı',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  runApp(const KelimeUygulamasi());
}

class KelimeUygulamasi extends StatelessWidget {
  const KelimeUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Masaüstü Kelime Hatırlatıcı',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  // Dinamik kelime listemiz
  List<Map<String, String>> _kelimeler = [];

  // Form ve süre kontrolleri
  final TextEditingController _enController = TextEditingController();
  final TextEditingController _trController = TextEditingController();
  final TextEditingController _saniyeController = TextEditingController(
    text: '10',
  );

  int _bildirimAraligiSaniye = 10;
  Timer? _zamanlayici;
  bool _calisiyorMu = false;

  @override
  void initState() {
    super.initState();
    _kelimeleriDosyadanYukle(); // Uygulama açılınca dosyadan kelimeleri oku
  }

  // 📂 DOSYA İŞLEMLERİ: Kelimelerin kaydedileceği txt dosyasını bulur
  Future<File> _getKelimeDosyasi() async {
    final dizin = await getApplicationDocumentsDirectory();
    return File('${dizin.path}/kelimelerim.txt');
  }

  // 📂 DOSYA İŞLEMLERİ: Txt dosyasından verileri okur ve listeye aktarır
  Future<void> _kelimeleriDosyadanYukle() async {
    try {
      final dosya = await _getKelimeDosyasi();
      if (await dosya.exists()) {
        final icerik = await dosya.readAsLines();
        List<Map<String, String>> yuklenenKelimeler = [];

        for (var satir in icerik) {
          if (satir.contains('|')) {
            var parcalar = satir.split('|');
            // Hatalı kısım düzeltildi: İndeksler köşeli parantez ile eklendi
            yuklenenKelimeler.add({'en': parcalar[0], 'tr': parcalar[1]});
          }
        }

        setState(() {
          _kelimeler = yuklenenKelimeler;
        });
      } else {
        // Dosya yoksa ilk açılış için varsayılan birkaç kelime ekle ve dosyayı yarat
        _kelimeler = [
          {'en': 'Accomplish', 'tr': 'Başarmak'},
          {'en': 'Benevolent', 'tr': 'Hayırsever'},
        ];
        _kelimeleriDosyayaKaydet();
      }
    } catch (e) {
      debugPrint("Dosya okuma hatası: $e");
    }
  }

  // 📂 DOSYA İŞLEMLERİ: Listeyi "ingilizce|türkçe" formatında txt dosyasına yazar
  Future<void> _kelimeleriDosyayaKaydet() async {
    final dosya = await _getKelimeDosyasi();
    List<String> satirlar = _kelimeler
        .map((k) => "${k['en']}|${k['tr']}")
        .toList();
    await dosya.writeAsString(satirlar.join('\n'));
  }

  // ➕ YENİ KELİME EKLEME FONKSİYONU
  void _kelimeEkle() {
    final enText = _enController.text.trim();
    final trText = _trController.text.trim();

    if (enText.isEmpty || trText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen her iki alanı da doldurun!')),
      );
      return;
    }

    setState(() {
      _kelimeler.add({'en': enText, 'tr': trText});
      _enController.clear();
      _trController.clear();
    });

    _kelimeleriDosyayaKaydet(); // Dosyayı güncelle

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kelime başarıyla kaydedildi!')),
    );
  }

  // 🔔 GERÇEK MASAÜSTÜ BİLDİRİMİ GÖNDERME FONKSİYONU
  void _gercekMasaustuBildirimiGonder() {
    if (_kelimeler.isEmpty) return;

    final rastgele = Random();
    final secilenKelime = _kelimeler[rastgele.nextInt(_kelimeler.length)];

    // Windows'un en iri font şablonunu tetikler
    LocalNotification notification = LocalNotification(
      title: "${secilenKelime['en']!.toUpperCase()}", // İngilizce büyük harf
      body: "Anlamı: ${secilenKelime['tr']}", // Türkçe karşılığı
      silent: false,
    );

    notification.show();
  }

  // ⏱ Zamanlayıcıyı başlatan veya güncelleyen fonksiyon
  void _zamanlayiciyiBaslat() {
    _zamanlayici?.cancel(); // Eski zamanlayıcı varsa önce durdur
    _zamanlayici = Timer.periodic(Duration(seconds: _bildirimAraligiSaniye), (
      timer,
    ) {
      _gercekMasaustuBildirimiGonder();
    });
  }

  void _hatirlaticiKapatAc() {
    if (_kelimeler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listede kelime yok! Önce kelime ekleyin.'),
        ),
      );
      return;
    }

    setState(() {
      if (_calisiyorMu) {
        _zamanlayici?.cancel();
        _calisiyorMu = false;
      } else {
        _calisiyorMu = true;
        _zamanlayiciyiBaslat();
        _gercekMasaustuBildirimiGonder(); // İlk bildirimi hemen at
      }
    });
  }

  // ⏱ Süre kutusu değiştiğinde tetiklenen fonksiyon
  void _sureyiGuncelle(String deger) {
    final yeniSure = int.tryParse(deger);
    if (yeniSure != null && yeniSure > 0) {
      setState(() {
        _bildirimAraligiSaniye = yeniSure;
      });
      // Hatırlatıcı zaten çalışıyorsa yeni süreye otomatik adapte et
      if (_calisiyorMu) {
        _zamanlayiciyiBaslat();
      }
    }
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _enController.dispose();
    _trController.dispose();
    _saniyeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelişmiş Kelime Hatırlatıcı (Saniye Ayarlı)'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // SOL PANEL: Kontroller ve Ayarlar
            Expanded(
              flex: 1,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Icon(
                          _calisiyorMu ? Icons.alarm_on : Icons.alarm_off,
                          size: 64,
                          color: _calisiyorMu ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(height: 10),

                        // ⏱ Saniye Ayar Kutusu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Sıklık: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: _saniyeController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: _sureyiGuncelle,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const Text(' saniyede bir'),
                          ],
                        ),
                        const SizedBox(height: 15),

                        ElevatedButton.icon(
                          onPressed: _hatirlaticiKapatAc,
                          icon: Icon(
                            _calisiyorMu ? Icons.stop : Icons.play_arrow,
                          ),
                          label: Text(
                            _calisiyorMu
                                ? 'Hatırlatıcıyı Durdur'
                                : 'Hatırlatıcıyı Başlat',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _calisiyorMu
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                          ),
                        ),
                        const Divider(height: 40),
                        const Text(
                          'Yeni Kelime Ekle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _enController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'İngilizce',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _trController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Türkçe Anlamı',
                          ),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: _kelimeEkle,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: const Text('Listeye ve Dosyaya Ekle'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // SAĞ PANEL: Kelime Listesi
            Expanded(
              flex: 1,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Kayıtlı Kelimeler (${_kelimeler.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _kelimeler.isEmpty
                            ? const Center(
                                child: Text('Henüz kelime eklenmedi.'),
                              )
                            : ListView.builder(
                                itemCount: _kelimeler.length,
                                itemBuilder: (context, index) {
                                  final item = _kelimeler[index];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.translate,
                                      color: Colors.blue,
                                    ),
                                    title: Text(
                                      item['en']!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(item['tr']!),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _kelimeler.removeAt(index);
                                        });
                                        _kelimeleriDosyayaKaydet();
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
