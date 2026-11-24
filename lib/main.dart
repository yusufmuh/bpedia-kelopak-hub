import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:daily_checkin/daily_checkin.dart';
import 'package:roda_sabtu/roda_sabtu.dart';
import 'package:misi_belanja/misi_belanja.dart';

void main() {
  runApp(const BpediaKelopakApp());
}

/// Tema warna resmi Bpedia Kelopak
class KelopakTheme {
  static const Color pearl = Color(0xfffffdfd);
  static const Color blush = Color(0xfff9f0ef);
  static const Color blushSoft = Color(0xfff6cfda);
  static const Color berry = Color(0xff982149);
  static const Color plum = Color(0xff4b1c2e);
  static const Color gold = Color(0xffeaa023);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pearl,
        colorScheme: ColorScheme.fromSeed(
          seedColor: berry,
          primary: berry,
          surface: pearl,
          onPrimary: Colors.white,
          onSurface: plum,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: pearl,
          foregroundColor: plum,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          color: blush,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: berry,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
}

class BpediaKelopakApp extends StatelessWidget {
  const BpediaKelopakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bpedia Kelopak',
      debugShowCheckedModeBanner: false,
      theme: KelopakTheme.lightTheme,
      home: const BpediaKelopakHomePage(),
    );
  }
}

class BpediaKelopakHomePage extends StatefulWidget {
  const BpediaKelopakHomePage({super.key});

  @override
  State<BpediaKelopakHomePage> createState() => _BpediaKelopakHomePageState();
}

class _BpediaKelopakHomePageState extends State<BpediaKelopakHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State Dompet Terpadu Kelopak
  int _balance = 0; // Saldo Kelopak (1 Kelopak = Rp100)
  int _products = 0; // Jumlah hak produk gratis yang dimiliki

  // State PRD 1: Daily Check-in
  int _streak = 0;
  int? _lastClaimDay;
  int _simulatedDay = 20780; // Offset hari WIB untuk simulasi (24 Nov 2026)

  // State PRD 2: Roda Sabtu
  int? _spinDay;
  String _lastSpinResult = '';
  int _stock = 1; // Stok demo produk gratis

  // State PRD 3: Misi Belanja
  int _earnedMissions = 0; // Jumlah tahap misi yang telah diselesaikan
  final Set<int> _usedVouchers = <int>{};
  final List<String> _orderHistory = <String>[];

  // Riwayat Transaksi Ledger
  final List<String> _activityLogs = <String>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _claimedToday => _lastClaimDay == _simulatedDay;

  DateTime get _currentDate =>
      DateTime.fromMillisecondsSinceEpoch(_simulatedDay * 86400000, isUtc: true);

  String get _currentDateFormatted {
    final d = _currentDate;
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final days = [
      '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year} (WIB)';
  }

  bool get _isSaturday => _currentDate.weekday == DateTime.saturday;
  bool get _hasSpunThisSaturday => _spinDay == _simulatedDay;

  void _log(String msg) {
    setState(() {
      _activityLogs.insert(0, '[${_currentDate.day}/${_currentDate.month}] $msg');
      if (_activityLogs.length > 20) _activityLogs.removeLast();
    });
  }

  // PRD 1: Handler Check-in
  void _handleCheckIn() {
    if (_claimedToday) return;

    final award = evaluateCheckIn(
      today: _simulatedDay,
      last: _lastClaimDay,
      streak: _streak,
    );

    if (award != null) {
      setState(() {
        _streak = award.streak;
        _balance += award.kelopak;
        _lastClaimDay = _simulatedDay;
        if (award.product) {
          _products++;
        }
      });

      final isMilestone = award.streak % 7 == 0;
      final msg = isMilestone
          ? 'Selamat! Check-in Hari ke-${award.streak} berhasil (+1 harian & bonus +3 Kelopak = +4 Kelopak)!'
          : 'Check-in Hari ke-${award.streak} berhasil (+1 Kelopak)';

      _log(msg);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: KelopakTheme.berry,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // PRD 2: Handler Putar Roda Sabtu
  void _handleSpin() {
    if (!_isSaturday || _hasSpunThisSaturday) return;

    final roll = math.Random().nextInt(100);
    final winProduct = demoProduct(remaining: _stock, roll: roll);

    setState(() {
      _spinDay = _simulatedDay;
      if (winProduct) {
        _stock--;
        _products++;
        _lastSpinResult = 'Selamat! Anda memenangkan 1 Produk Gratis!';
      } else {
        _balance += 3;
        _lastSpinResult = 'Selamat! Anda memenangkan 3 Kelopak!';
      }
    });

    _log('Roda Sabtu: $_lastSpinResult');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_lastSpinResult),
        backgroundColor: KelopakTheme.berry,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // PRD 3: Handler Simulasi Pesanan Selesai
  void _handleSimulateOrder() {
    if (_earnedMissions >= demoStages.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua tahap misi saat ini telah selesai!')),
      );
      return;
    }

    final stageIndex = _earnedMissions;
    final currentTerms = demoStages[stageIndex];
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final qualifiesOrder = qualifies(
      terms: currentTerms,
      subtotal: currentTerms.threshold,
      completed: true,
      alreadyCounted: _orderHistory.contains(orderId),
    );

    if (qualifiesOrder) {
      setState(() {
        _orderHistory.add(orderId);
        _earnedMissions++;
      });

      final msg =
          'Pesanan selesai ${rupiah(currentTerms.threshold)}! Voucher ${rupiah(currentTerms.discount)} terbit untuk Tahap ${stageIndex + 1}.';
      _log(msg);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: KelopakTheme.berry,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // PRD 3: Handler Uji Voucher di Pesanan Berikutnya
  void _handleRedeemVoucher(int stageIndex) {
    if (_usedVouchers.contains(stageIndex)) return;

    final terms = demoStages[stageIndex];
    final sourceOrder = _orderHistory.length > stageIndex ? _orderHistory[stageIndex] : 'ORD-OLD';
    const nextOrder = 'ORD-NEXT-999';

    final valid = mayRedeem(
      terms: terms,
      subtotal: terms.redeemMinimum,
      sourceOrder: sourceOrder,
      nextOrder: nextOrder,
      used: false,
    );

    if (valid) {
      setState(() {
        _usedVouchers.add(stageIndex);
      });

      final msg =
          'Voucher ${rupiah(terms.discount)} berhasil dipakai di pesanan ${rupiah(terms.redeemMinimum)} (Hemat ${rupiah(terms.discount)}).';
      _log(msg);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: KelopakTheme.berry,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Kontrol Simulasi: Maju Kalender
  void _advanceDays(int days) {
    setState(() {
      _simulatedDay += days;
    });
    _log('Kalender simulasi maju $days hari.');
  }

  // Kontrol Simulasi: Reset
  void _resetSimulation() {
    setState(() {
      _balance = 0;
      _products = 0;
      _streak = 0;
      _lastClaimDay = null;
      _spinDay = null;
      _lastSpinResult = '';
      _stock = 1;
      _earnedMissions = 0;
      _usedVouchers.clear();
      _orderHistory.clear();
      _activityLogs.clear();
    });
    _log('Simulasi di-reset ke status awal.');
  }

  @override
  Widget build(BuildContext context) {
    final rupiahBalance = _balance * 100;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: KelopakTheme.blushSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.spa, color: KelopakTheme.berry, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bpedia Kelopak',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: KelopakTheme.plum,
                  ),
                ),
                Text(
                  'Program Hadiah & Loyalitas',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Dompet Kelopak
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: KelopakTheme.blush,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KelopakTheme.blushSoft),
            ),
            child: Row(
              children: [
                const Icon(Icons.spa, color: KelopakTheme.berry, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$_balance Kelopak (Rp${rupiahBalance.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: KelopakTheme.berry,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: KelopakTheme.berry,
          unselectedLabelColor: Colors.black45,
          indicatorColor: KelopakTheme.berry,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today, size: 18), text: 'Check-in'),
            Tab(icon: Icon(Icons.rotate_right, size: 20), text: 'Roda Sabtu'),
            Tab(icon: Icon(Icons.shopping_bag_outlined, size: 18), text: 'Misi Belanja'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner Bipy & Waktu Simulasi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: KelopakTheme.blush,
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: KelopakTheme.berry),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waktu Sistem: $_currentDateFormatted',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KelopakTheme.plum,
                    ),
                  ),
                ),
                if (_products > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: KelopakTheme.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_products Hak Produk',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Tiga Konten Modul
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Check-in Harian
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: DailyCheckInView(
                        streak: _streak,
                        claimed: _claimedToday,
                        products: _products,
                        onClaim: _handleCheckIn,
                      ),
                    ),
                  ),
                ),

                // Tab 2: Roda Sabtu
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: SaturdayWheel(
                        available: _isSaturday,
                        remaining: _stock,
                        spun: _hasSpunThisSaturday,
                        lastResult: _lastSpinResult,
                        previewDate: _currentDateFormatted,
                        onSpin: _handleSpin,
                      ),
                    ),
                  ),
                ),

                // Tab 3: Misi Belanja Bertahap (Suf)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: ShoppingMissions(
                        earned: _earnedMissions,
                        used: _usedVouchers,
                        onOrder: _handleSimulateOrder,
                        onRedeem: _handleRedeemVoucher,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Panel Alat Simulasi & Pengujian Cepat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Alat Simulasi & Pengujian QA:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: _resetSimulation,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 20),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Reset', style: TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: () => _advanceDays(1),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('+1 Hari', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton(
                      onPressed: () => _advanceDays(7),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('+7 Hari (Lompat Minggu)', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        // Lompat ke Sabtu terdekat
                        var step = 1;
                        while ((_simulatedDay + step) % 7 != 4) {
                          // Day modulo check for Saturday
                          final target = DateTime.fromMillisecondsSinceEpoch(
                              (_simulatedDay + step) * 86400000,
                              isUtc: true);
                          if (target.weekday == DateTime.saturday) break;
                          step++;
                        }
                        _advanceDays(step);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Lompat ke Sabtu', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
