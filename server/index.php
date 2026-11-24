<?php
declare(strict_types=1);

/*
 * Demo API simulator for backend teams (the Flutter app never calls it).
 *
 * POST JSON to this file. `open` creates a session and returns `session`;
 * every other action needs the header `X-Demo-Session: <session>`, and every
 * action except `read` also needs the latest `revision` and `day` (else 409).
 *
 *   read                                 current state
 *   checkin                              Check-in Harian (checkin.php)
 *   spin                                 Roda Sabtu, roll 0..9999 (spin.php)
 *   order   {subtotal, order}            completed order for Misi Belanja (missions.php)
 *   redeem  {stage, subtotal, order}     use voucher `stage` (0 = Tahap 1) on another order
 *   advance {step}                       move the demo calendar 1..7 days forward
 *   promo   {active}                     Roda Sabtu promo on/off
 *   refill                               restore the wheel's product stock
 *
 * Business rules live in checkin.php, spin.php and missions.php, copied
 * unchanged from the module repos.
 *
 * Abuse limits: `open` is limited per client IP and hour (the IP is stored
 * only as a hash, for 24 hours). When DEMO_MAX_SESSIONS is reached, the
 * oldest session that never changed anything is evicted to make room, so
 * one client cannot lock everyone else out. Only actions that change data
 * refresh a session's age; `read` does not.
 */

require __DIR__ . '/checkin.php';
require __DIR__ . '/spin.php';
require __DIR__ . '/missions.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

const DEMO_PRODUCT_STOCK = 1;
const DEMO_MAX_OFFSET_DAYS = 365;
const DEMO_SESSION_TTL_SECONDS = 7 * 86400;
const DEMO_MAX_SESSIONS = 5000;
const DEMO_MAX_OPENS_PER_IP_HOUR = 20;

function reply(int $code, array $body): never
{
    http_response_code($code);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    exit;
}

function dayNow(): int
{
    return CheckInEngine::wibDayOf(time());
}

function optionalInt(array $s, string $key): ?int
{
    return is_int($s[$key] ?? null) ? $s[$key] : null;
}

/** Stored state plus the views a client needs: WIB day, check-in, wheel odds and missions. */
function snapshot(array $s): array
{
    $day = dayNow() + (int) $s['offset'];
    $lastDay = optionalInt($s, 'lastDay');
    $streak = optionalInt($s, 'streak') ?? 0;
    $live = CheckInEngine::liveStreak($day, $lastDay, $streak);
    $claimed = CheckInEngine::isClaimedOn($day, $lastDay);
    $config = rodaDemoConfig();
    $stock = max(0, optionalInt($s, 'stock') ?? 0);
    $weights = rodaEffectiveWeights($config, $stock);
    $odds = [];
    foreach ($config['prizes'] as $index => $prize) {
        $odds[] = ['id' => $prize['id'], 'label' => $prize['label'], 'weight' => $weights[$index]];
    }
    $s['day'] = $day;
    $s['date'] = CheckInEngine::wibDateOf($day);
    $s['weekday'] = CheckInEngine::wibWeekdayOf($day);
    $s['checkin'] = [
        'liveStreak' => $live,
        'claimedToday' => $claimed,
        'filledInWeek' => CheckInEngine::filledInWeek($live, $claimed),
        'dayInMonthCycle' => CheckInEngine::dayInMonthCycle($live, $claimed),
    ];
    $s['wheel'] = [
        'eligibility' => rodaSpinEligibility($day, optionalInt($s, 'spinDay'), (bool) ($s['promoActive'] ?? true)),
        'daysUntilSaturday' => rodaDaysUntilSaturday($day),
        'configVersion' => $config['version'],
        'odds' => $odds,
        'stock' => $stock,
        'shippingNote' => $config['shippingNote'],
    ];
    $s['mission'] = missionSnapshot($s, $day);
    return $s;
}

function smallInt(array $body, string $name, int $max): int
{
    $v = $body[$name] ?? null;
    if (!is_int($v) || $v < 0 || $v > $max) {
        throw new DomainException('Parameter simulasi tidak valid.');
    }
    return $v;
}

function flag(array $body, string $name): bool
{
    $v = $body[$name] ?? null;
    if (!is_bool($v)) {
        throw new DomainException('Parameter simulasi tidak valid.');
    }
    return $v;
}

function ref(array $body): string
{
    $v = $body['order'] ?? null;
    if (!is_string($v) || !preg_match('/^[a-zA-Z0-9-]{1,64}$/D', $v)) {
        throw new DomainException('Referensi pesanan tidak valid.');
    }
    return $v;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    reply(405, ['error' => 'Gunakan POST.']);
}
$raw = file_get_contents('php://input', false, null, 0, 4097);
if ($raw === false) {
    reply(400, ['error' => 'Permintaan tidak terbaca.']);
}
if (strlen($raw) > 4096) {
    reply(413, ['error' => 'Permintaan terlalu besar.']);
}
$body = json_decode($raw, true);
if (!is_array($body)) {
    reply(400, ['error' => 'JSON tidak valid.']);
}
$action = $body['action'] ?? '';
$key = $_SERVER['HTTP_X_DEMO_SESSION'] ?? '';
if ($action !== 'open' && !preg_match('/^[a-f0-9]{32}$/D', $key)) {
    reply(401, ['error' => 'Kode sesi demo tidak valid.']);
}

try {
    // Sibling of public_html, so it survives a web deployment and is never served.
    $dir = getenv('KELOPAK_DATA_DIR') ?: dirname(__DIR__, 2) . '/kelopak-demo-data';
    if (!is_dir($dir) && !mkdir($dir, 0700, true) && !is_dir($dir)) {
        throw new RuntimeException('Data folder unavailable.');
    }
    $db = new PDO('sqlite:' . $dir . '/demo.sqlite', null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $db->exec('PRAGMA busy_timeout=5000');
    $db->exec('CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, state TEXT NOT NULL, updated INTEGER NOT NULL)');
    $db->exec('CREATE TABLE IF NOT EXISTS opens (ip TEXT NOT NULL, hour INTEGER NOT NULL, n INTEGER NOT NULL, PRIMARY KEY(ip, hour))');
    $db->exec('BEGIN IMMEDIATE');
    if ($action === 'open') {
        $hour = intdiv(time(), 3600);
        $client = hash('sha256', (string) ($_SERVER['REMOTE_ADDR'] ?? ''));
        $db->exec('DELETE FROM opens WHERE hour < ' . ($hour - 24));
        $db->prepare('INSERT INTO opens(ip, hour, n) VALUES(?, ?, 1) ON CONFLICT(ip, hour) DO UPDATE SET n = n + 1')
            ->execute([$client, $hour]);
        $count = $db->prepare('SELECT n FROM opens WHERE ip = ? AND hour = ?');
        $count->execute([$client, $hour]);
        if ((int) $count->fetchColumn() > DEMO_MAX_OPENS_PER_IP_HOUR) {
            $db->exec('ROLLBACK');
            reply(429, ['error' => 'Terlalu banyak sesi demo baru. Coba lagi dalam satu jam.']);
        }
        $db->exec('DELETE FROM accounts WHERE updated < ' . (time() - DEMO_SESSION_TTL_SECONDS));
        if ((int) $db->query('SELECT COUNT(*) FROM accounts')->fetchColumn() >= DEMO_MAX_SESSIONS) {
            // Full: drop the oldest session that never changed anything
            // (revision 0), else the oldest one.
            $db->exec("DELETE FROM accounts WHERE id = (SELECT id FROM accounts ORDER BY json_extract(state, '$.revision') > 0, updated LIMIT 1)");
        }
        $key = bin2hex(random_bytes(16));
        $s = [
            'balance' => 0,
            'streak' => 0,
            'lastDay' => null,
            'products' => 0,
            'spinDay' => null,
            'spinPrizeId' => null,
            'spinResult' => '',
            'stock' => DEMO_PRODUCT_STOCK,
            'promoActive' => true,
            'vouchers' => [],
            'countedOrders' => [],
            'offset' => 0,
            'revision' => 0,
            'history' => [],
        ];
        $view = snapshot($s);
        $db->prepare('INSERT INTO accounts VALUES(?,?,?)')->execute([hash('sha256', $key), json_encode($s), time()]);
        $db->exec('COMMIT');
        reply(201, ['session' => $key, 'state' => $view]);
    }
    $id = hash('sha256', $key);
    $q = $db->prepare('SELECT state FROM accounts WHERE id=? AND updated>=?');
    $q->execute([$id, time() - DEMO_SESSION_TTL_SECONDS]);
    $row = $q->fetchColumn();
    if ($row === false) {
        $db->exec('ROLLBACK');
        reply(401, ['error' => 'Sesi demo kedaluwarsa atau kode salah.']);
    }
    $s = json_decode($row, true, 512, JSON_THROW_ON_ERROR);
    $day = dayNow() + (int) $s['offset'];
    if ($action !== 'read') {
        if (($body['revision'] ?? null) !== $s['revision'] || ($body['day'] ?? null) !== $day) {
            $db->exec('ROLLBACK');
            reply(409, ['error' => 'Progres berubah. Periksa hasil terbaru.', 'state' => snapshot($s)]);
        }
        $tx = bin2hex(random_bytes(5));
        switch ($action) {
            case 'checkin':
                $label = claimDay($s, $day);
                break;
            case 'spin':
                $prize = claimSaturdaySpin($s, $day, random_int(0, RODA_TOTAL_WEIGHT - 1));
                $label = 'Roda Sabtu · ' . $prize['label'];
                break;
            case 'order':
                $label = recordDemoOrder($s, smallInt($body, 'subtotal', 100000000), ref($body), true, $day);
                break;
            case 'redeem':
                $label = useDemoVoucher(
                    $s,
                    smallInt($body, 'stage', count(MISSION_DEMO_STAGES) - 1),
                    smallInt($body, 'subtotal', 100000000),
                    ref($body),
                    $day,
                );
                break;
            case 'advance':
                $step = smallInt($body, 'step', 7);
                if ($step < 1 || (int) $s['offset'] + $step > DEMO_MAX_OFFSET_DAYS) {
                    throw new DomainException('Batas kalender simulasi tercapai.');
                }
                $s['offset'] = (int) $s['offset'] + $step;
                $label = 'Kalender demo maju ' . $step . ' hari';
                break;
            case 'promo':
                $s['promoActive'] = flag($body, 'active');
                $label = $s['promoActive'] ? 'Promo Roda Sabtu aktif' : 'Promo Roda Sabtu dijeda';
                break;
            case 'refill':
                $s['stock'] = DEMO_PRODUCT_STOCK;
                $label = 'Stok produk Roda Sabtu diisi ulang';
                break;
            default:
                throw new DomainException('Tindakan tidak dikenal.');
        }
        $s['revision']++;
        array_unshift($s['history'], ['id' => $tx, 'day' => $day, 'label' => $label]);
        $s['history'] = array_slice($s['history'], 0, 24);
        // Only a change keeps the session alive; reading does not.
        $db->prepare('UPDATE accounts SET state=?,updated=? WHERE id=?')->execute([json_encode($s), time(), $id]);
    }
    $view = snapshot($s);
    $db->exec('COMMIT');
    reply(200, ['state' => $view]);
} catch (DomainException $e) {
    if (isset($db)) {
        $db->exec('ROLLBACK');
    }
    reply(422, ['error' => $e->getMessage()]);
} catch (Throwable $e) {
    reply(503, ['error' => 'Layanan demo sementara tidak tersedia. Coba muat ulang progres.']);
}
