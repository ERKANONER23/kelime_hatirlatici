import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path_provider/path_provider.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows bildirim sistemini kur
  await localNotifier.setup(
    appName: 'Kelime Hatırlatıcı',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  // Otomatik başlangıç ayarlarını yapılandır
  launchAtStartup.setup(
    appName: 'Kelime Hatirlatici',
    appPath: Platform.resolvedExecutable,
    args: ['--autostart'],
  );

  // Pencere yöneticisini başlat
  await windowManager.ensureInitialized();

  // Windows'un varsayılan kapatma (X) davranışını devre dışı bırakıp Flutter'a devrediyoruz
  WindowOptions windowOptions = const WindowOptions(
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(
      true,
    ); // X'e basınca direkt kapanmayı engelle
  });

  // Eğer bilgisayar açılışında otomatik tetiklendiyse pencereyi gizle
  bool arkaPlandaBaslasin = args.contains('--autostart');
  if (arkaPlandaBaslasin) {
    await windowManager.hide();
  } else {
    await windowManager.show();
  }

  runApp(KelimeUygulamasi(otomatikBaslat: arkaPlandaBaslasin));
}

class KelimeUygulamasi extends StatelessWidget {
  final bool otomatikBaslat;

  const KelimeUygulamasi({super.key, this.otomatikBaslat = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Masaüstü Kelime Hatırlatıcı',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: AnaSayfa(otomatikBaslat: otomatikBaslat),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  final bool otomatikBaslat;
  const AnaSayfa({super.key, required this.otomatikBaslat});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with WindowListener, TrayListener {
  List<Map<String, String>> _kelimeler = [];
  final TextEditingController _enController = TextEditingController();
  final TextEditingController _trController = TextEditingController();
  final TextEditingController _saniyeController = TextEditingController(
    text: '10',
  );

  int _bildirimAraligiSaniye = 10;
  Timer? _zamanlayici;
  bool _calisiyorMu = false;
  bool _baslangictaAcilsinMi = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this); // Pencere olaylarını dinle
    trayManager.addListener(this); // Sistem tepsisi olaylarını dinle
    _sistemTepsisiKur(); // Sağ alttaki simgeyi hazırla

    _kelimeleriDosyadanYukle().then((_) {
      if (widget.otomatikBaslat) {
        _hatirlaticiKapatAc();
      }
    });
    _baslangicDurumunuKontrolEt();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _zamanlayici?.cancel();
    _enController.dispose();
    _trController.dispose();
    _saniyeController.dispose();
    super.dispose();
  }

  // 🛠️ SİZİN KLASÖRÜNÜZE VE .ICO DOSYALARINIZA GÖRE GÜNCELLENEN KISIM
  Future<void> _sistemTepsisiKur() async {
    try {
      // Sağ alttaki ana ikon 'ico/app_icon.ico' olarak ayarlandı
      await trayManager.setIcon('ico/app_icon.ico');
    } catch (e) {
      debugPrint("Ana ikon yüklenemedi: $e");
    }

    // Sizin hazırladığınız .ico dosyaları menü elemanlarına bağlandı
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'goster',
          label: 'Programı Göster',
          icon: 'ico/open.ico', // Göster ikonu
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'kapat',
          label: 'Kapat',
          icon: 'ico/closed.ico', // Kapat ikonu
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'goster') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'kapat') {
      _zamanlayici?.cancel();
      await trayManager.destroy();
      exit(0);
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();

      LocalNotification notification = LocalNotification(
        title: "Kelime Hatırlatıcı",
        body: "Uygulama arka planda çalışmaya devam ediyor.",
        silent: true,
      );
      notification.show();
    }
  }

  Future<void> _baslangicDurumunuKontrolEt() async {
    bool kontrol = await launchAtStartup.isEnabled();
    setState(() {
      _baslangictaAcilsinMi = kontrol;
    });
  }

  Future<void> _baslangicAyariniDegistir(bool deger) async {
    if (deger) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    setState(() {
      _baslangictaAcilsinMi = deger;
    });
  }

  Future<File> _getKelimeDosyasi() async {
    final dizin = await getApplicationDocumentsDirectory();
    return File('${dizin.path}/kelimelerim.txt');
  }

  Future<void> _kelimeleriDosyadanYukle() async {
    try {
      final dosya = await _getKelimeDosyasi();
      if (await dosya.exists()) {
        final icerik = await dosya.readAsLines();
        List<Map<String, String>> yuklenenKelimeler = [];

        for (var satir in icerik) {
          if (satir.contains('|')) {
            List<String> parcalar = satir.split('|');
            if (parcalar.length >= 2) {
              String ingilizce = parcalar.elementAt(0);
              String turkce = parcalar.elementAt(1);

              yuklenenKelimeler.add({'en': ingilizce, 'tr': turkce});
            }
          }
        }
        setState(() {
          _kelimeler = yuklenenKelimeler;
        });
      } else {
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

  Future<void> _kelimeleriDosyayaKaydet() async {
    final dosya = await _getKelimeDosyasi();
    List<String> satirlar = _kelimeler
        .map((k) => "${k['en']}|${k['tr']}")
        .toList();
    await dosya.writeAsString(satirlar.join('\n'));
  }

  void _kelimeEkle() {
    final enText = _enController.text.trim();
    final trText = _trController.text.trim();

    if (enText.isEmpty || trText.isEmpty) return;

    setState(() {
      _kelimeler.add({'en': enText, 'tr': trText});
      _enController.clear();
      _trController.clear();
    });
    _kelimeleriDosyayaKaydet();
  }

  void _gercekMasaustuBildirimiGonder() {
    if (_kelimeler.isEmpty) return;

    final rastgele = Random();
    final secilenKelime = _kelimeler[rastgele.nextInt(_kelimeler.length)];

    LocalNotification notification = LocalNotification(
      title: secilenKelime['en']!.toUpperCase(),
      body: "Anlamı: ${secilenKelime['tr']}",
      silent: false,
    );
    notification.show();
  }

  void _zamanlayiciyiBaslat() {
    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(Duration(seconds: _bildirimAraligiSaniye), (
      timer,
    ) {
      _gercekMasaustuBildirimiGonder();
    });
  }

  void _hatirlaticiKapatAc() {
    if (_kelimeler.isEmpty) return;

    setState(() {
      if (_calisiyorMu) {
        _zamanlayici?.cancel();
        _calisiyorMu = false;
      } else {
        _calisiyorMu = true;
        _zamanlayiciyiBaslat();
        _gercekMasaustuBildirimiGonder();
      }
    });
  }

  void _sureyiGuncelle(String deger) {
    final yeniSure = int.tryParse(deger);
    if (yeniSure != null && yeniSure > 0) {
      setState(() {
        _bildirimAraligiSaniye = yeniSure;
      });
      if (_calisiyorMu) {
        _zamanlayiciyiBaslat();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kesintisiz Kelime Hatırlatıcı'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
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
                        SwitchListTile(
                          title: const Text(
                            'Bilgisayar açılınca otomatik başlasın',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: _baslangictaAcilsinMi,
                          onChanged: _baslangicAyariniDegistir,
                        ),
                        const Divider(),
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
                        const Divider(height: 30),
                        const Text(
                          'Yeni Kelime Ekle',
                          style: TextStyle(
                            fontSize: 16,
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
                          child: const Text('Listeye Ekle'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
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
