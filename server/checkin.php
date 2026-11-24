<?php
declare(strict_types=1);

/**
 * Check-in Harian, sisi server: cermin persis engine Dart package:daily_checkin.
 *
 * Hari = tanggal WIB (UTC+07.00, tanpa DST), dihitung server, bukan jam perangkat.
 * +1 Kelopak per tanggal, satu klaim per tanggal. Hari ke-7, 14, 21, ... beruntun: +3 bonus.
 * Hari ke-30, 60, ... beruntun: 1 hak produk gratis. Bolong satu tanggal: rentetan mulai dari 1,
 * saldo dan hak yang sudah didapat tidak hilang. 1 Kelopak = Rp100.
 *
 * Dipakai oleh router demo hub (server/index.php) lewat claimDay(). Jalankan
 * `php server/checkin.php` untuk swa-uji aturan yang sama dengan test Dart.
 */
final class CheckInEngine
{
    public const DAILY_KELOPAK = 1;
    public const BONUS_EVERY = 7;
    public const BONUS_KELOPAK = 3;
    public const PRODUCT_EVERY = 30;

    private const WIB_OFFSET_SECONDS = 7 * 3600;
    private const SECONDS_PER_DAY = 86400;

    private function __construct()
    {
    }

    /** Hari WIB sejak 1 Januari 1970 (hari 0 = Kamis); sebelum epoch dibulatkan ke bawah. */
    public static function wibDayOf(int $unixSeconds): int
    {
        $shifted = $unixSeconds + self::WIB_OFFSET_SECONDS;
        return intdiv($shifted - self::floorMod($shifted, self::SECONDS_PER_DAY), self::SECONDS_PER_DAY);
    }

    /** 1 = Senin ... 6 = Sabtu, 7 = Minggu. */
    public static function wibWeekdayOf(int $wibDay): int
    {
        return self::floorMod($wibDay + 3, 7) + 1;
    }

    /** Tanggal kalender WIB dari hari WIB, format Y-m-d. */
    public static function wibDateOf(int $wibDay): string
    {
        return gmdate('Y-m-d', $wibDay * self::SECONDS_PER_DAY);
    }

    /**
     * Klaim pada hari WIB $today. Null bila tanggal itu sudah diklaim atau jam mundur.
     *
     * @return array{streak: int, dailyKelopak: int, bonusKelopak: int, productEntitled: bool, totalKelopak: int}|null
     */
    public static function evaluate(int $today, ?int $lastClaimDay, int $streak): ?array
    {
        if ($lastClaimDay !== null && $today <= $lastClaimDay) {
            return null;
        }
        $continues = $lastClaimDay === $today - 1 && $streak > 0;
        $next = ($continues ? $streak : 0) + 1;
        $bonus = $next % self::BONUS_EVERY === 0 ? self::BONUS_KELOPAK : 0;
        return [
            'streak' => $next,
            'dailyKelopak' => self::DAILY_KELOPAK,
            'bonusKelopak' => $bonus,
            'productEntitled' => $next % self::PRODUCT_EVERY === 0,
            'totalKelopak' => self::DAILY_KELOPAK + $bonus,
        ];
    }

    /** Rentetan yang masih hidup pada $today; 0 bila belum pernah klaim atau ada tanggal terlewat. */
    public static function liveStreak(int $today, ?int $lastClaimDay, int $streak): int
    {
        if ($lastClaimDay === null || $lastClaimDay < $today - 1 || $streak < 0) {
            return 0;
        }
        return $streak;
    }

    /** True bila $today tidak bisa diklaim lagi (sudah diklaim, atau jam mundur). */
    public static function isClaimedOn(int $today, ?int $lastClaimDay): bool
    {
        return $lastClaimDay !== null && $lastClaimDay >= $today;
    }

    /** Slot mekar di jejak 7 hari, 0..7. */
    public static function filledInWeek(int $liveStreak, bool $claimedToday): int
    {
        return self::positionInCycle($liveStreak, $claimedToday, self::BONUS_EVERY);
    }

    /** Progres menuju produk gratis, 0..30. */
    public static function dayInMonthCycle(int $liveStreak, bool $claimedToday): int
    {
        return self::positionInCycle($liveStreak, $claimedToday, self::PRODUCT_EVERY);
    }

    private static function positionInCycle(int $streak, bool $claimedToday, int $length): int
    {
        if ($streak <= 0) {
            return 0;
        }
        return $claimedToday ? ($streak - 1) % $length + 1 : $streak % $length;
    }

    private static function floorMod(int $value, int $divisor): int
    {
        $remainder = $value % $divisor;
        return $remainder < 0 ? $remainder + $divisor : $remainder;
    }
}

/**
 * Mencatat check-in pada state akun demo (kunci: streak, lastDay, balance, products).
 * Mengembalikan label riwayat; melempar DomainException bila tanggal WIB ini sudah diklaim.
 *
 * @param array<string, mixed> $state
 */
function claimDay(array &$state, int $today): string
{
    $lastDay = is_int($state['lastDay'] ?? null) ? $state['lastDay'] : null;
    $streak = is_int($state['streak'] ?? null) ? $state['streak'] : 0;
    $award = CheckInEngine::evaluate($today, $lastDay, $streak);
    if ($award === null) {
        throw new DomainException('Kamu sudah check-in hari ini. Kembali besok mulai 00.00 WIB.');
    }
    $balance = is_int($state['balance'] ?? null) ? $state['balance'] : 0;
    $products = is_int($state['products'] ?? null) ? $state['products'] : 0;
    $state['streak'] = $award['streak'];
    $state['lastDay'] = $today;
    $state['balance'] = $balance + $award['totalKelopak'];
    $state['products'] = $products + ($award['productEntitled'] ? 1 : 0);
    return checkInLabel($award);
}

/**
 * Label riwayat, contoh "+1 Kelopak + bonus 3 Kelopak · Hari ke-7".
 *
 * @param array{streak: int, dailyKelopak: int, bonusKelopak: int, productEntitled: bool, totalKelopak: int} $award
 */
function checkInLabel(array $award): string
{
    $label = '+' . $award['dailyKelopak'] . ' Kelopak';
    if ($award['bonusKelopak'] > 0) {
        $label .= ' + bonus ' . $award['bonusKelopak'] . ' Kelopak';
    }
    if ($award['productEntitled']) {
        $label .= ' + 1 produk gratis';
    }
    return $label . ' · Hari ke-' . $award['streak'];
}

/** Swa-uji aturan; mengembalikan kode keluar 0 bila semua cocok. */
function checkInSelfTest(): int
{
    $failures = [];
    $checks = 0;
    $expect = static function (mixed $actual, mixed $expected, string $what) use (&$failures, &$checks): void {
        $checks++;
        if ($actual !== $expected) {
            $failures[] = $what . ': dapat ' . var_export($actual, true) . ', harus ' . var_export($expected, true);
        }
    };
    $at = static fn (string $iso): int => (new DateTimeImmutable($iso))->getTimestamp();

    $expect(CheckInEngine::wibDayOf($at('2026-11-23T16:59:59Z')), 20780, 'wibDayOf 16.59.59 UTC');
    $expect(CheckInEngine::wibDayOf($at('2026-11-23T17:00:00Z')), 20781, 'wibDayOf 17.00 UTC');
    $expect(CheckInEngine::wibDateOf(20781), '2026-11-24', 'wibDateOf 20781');
    $expect(CheckInEngine::wibDayOf($at('1969-12-31T16:59:59Z')), -1, 'wibDayOf sebelum epoch');
    $expect(CheckInEngine::wibWeekdayOf(CheckInEngine::wibDayOf($at('2026-11-28T03:00:00Z'))), 6, 'Sabtu 28 Nov 2026');
    $expect(CheckInEngine::wibWeekdayOf(0), 4, 'hari 0 Kamis');
    $expect(CheckInEngine::wibWeekdayOf(-1), 3, 'hari -1 Rabu');

    $state = ['streak' => 0, 'lastDay' => null, 'balance' => 0, 'products' => 0];
    $totals = [7 => 10, 14 => 20, 21 => 30, 28 => 40, 30 => 42, 35 => 50, 60 => 84];
    $productDays = [];
    for ($day = 1; $day <= 60; $day++) {
        $label = claimDay($state, 20780 + $day);
        if (str_contains($label, 'produk gratis')) {
            $productDays[] = $day;
        }
        if (isset($totals[$day])) {
            $expect($state['balance'], $totals[$day], "total hari ke-$day");
        }
    }
    $expect($productDays, [30, 60], 'hari hak produk');
    $expect($state['products'], 2, 'jumlah hak produk');
    $bonusAward = CheckInEngine::evaluate(7, 6, 6);
    $expect($bonusAward === null ? null : checkInLabel($bonusAward), '+1 Kelopak + bonus 3 Kelopak · Hari ke-7', 'label bonus');

    $duplicate = false;
    try {
        claimDay($state, 20840);
    } catch (DomainException) {
        $duplicate = true;
    }
    $expect($duplicate, true, 'klaim ganda ditolak');
    $expect($state['balance'], 84, 'saldo tetap setelah klaim ganda');

    $reset = ['streak' => 0, 'lastDay' => null, 'balance' => 0, 'products' => 0];
    for ($day = 0; $day < 5; $day++) {
        claimDay($reset, 100 + $day);
    }
    claimDay($reset, 106);
    $expect($reset['streak'], 1, 'bolong: rentetan kembali ke 1');
    $expect($reset['balance'], 6, 'bolong: saldo lama aman');

    $expect(CheckInEngine::evaluate(100, 101, 4), null, 'jam mundur ditolak');
    $corrupt = CheckInEngine::evaluate(101, 100, -5);
    $expect($corrupt === null ? null : $corrupt['streak'], 1, 'rentetan rusak mulai dari 1');
    $expect(CheckInEngine::liveStreak(100, 98, 9), 0, 'liveStreak setelah bolong');
    $expect(CheckInEngine::liveStreak(100, 99, 9), 9, 'liveStreak kemarin');
    $expect(CheckInEngine::liveStreak(100, 100, 9), 9, 'liveStreak hari ini');
    $expect(CheckInEngine::isClaimedOn(100, 100), true, 'isClaimedOn hari ini');
    $expect(CheckInEngine::isClaimedOn(100, 99), false, 'isClaimedOn kemarin');

    $weekTable = [0 => [0, 0], 1 => [1, 1], 6 => [6, 6], 7 => [7, 0], 8 => [1, 1], 13 => [6, 6], 14 => [7, 0]];
    foreach ($weekTable as $streak => [$claimed, $open]) {
        $expect(CheckInEngine::filledInWeek($streak, true), $claimed, "filledInWeek $streak sudah");
        $expect(CheckInEngine::filledInWeek($streak, false), $open, "filledInWeek $streak belum");
    }
    $monthTable = [0 => [0, 0], 7 => [7, 7], 14 => [14, 14], 29 => [29, 29], 30 => [30, 0], 31 => [1, 1]];
    foreach ($monthTable as $streak => [$claimed, $open]) {
        $expect(CheckInEngine::dayInMonthCycle($streak, true), $claimed, "dayInMonthCycle $streak sudah");
        $expect(CheckInEngine::dayInMonthCycle($streak, false), $open, "dayInMonthCycle $streak belum");
    }

    foreach ($failures as $failure) {
        fwrite(STDERR, 'GAGAL ' . $failure . PHP_EOL);
    }
    fwrite(STDOUT, sprintf('checkin.php swa-uji: %d cek, %d gagal', $checks, count($failures)) . PHP_EOL);
    return $failures === [] ? 0 : 1;
}

if (PHP_SAPI === 'cli' && realpath((string) ($_SERVER['SCRIPT_FILENAME'] ?? '')) === __FILE__) {
    exit(checkInSelfTest());
}
