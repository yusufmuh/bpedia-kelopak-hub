<?php
declare(strict_types=1);

/*
 * Swa-uji server acuan Kelopak v3: aturan modul (checkin/spin/missions),
 * mesin hub (kelopak.php), dan lapisan HTTP (kelopak_http.php).
 *
 *   php server/selftest.php     keluar 0 bila semua cek lolos
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    return;
}

require_once __DIR__ . '/kelopak_http.php';

$checks = 0;
$failures = [];

function check(string $name, bool $ok): void
{
    global $checks, $failures;
    $checks++;
    if (!$ok) {
        $failures[] = $name;
    }
}

function noonOf(int $wibDay): int
{
    return $wibDay * 86400 + 5 * 3600;
}

/** Hari WIB Sabtu pertama sejak $from. */
function saturdayFrom(int $from): int
{
    return $from + rodaDaysUntilSaturday($from);
}

/** Pengundi tetap: mengembalikan $values berurutan. */
function fixedRandom(array $values): Closure
{
    return static function (int $min, int $max) use (&$values): int {
        $value = array_shift($values) ?? $min;
        return max($min, min($max, $value));
    };
}

function grant(array &$state, int $amount, int $day): void
{
    kelopakAddLedger($state, $day, $amount, 'demoGrant', 'Isi saldo uji');
}

function request(array $lines, int $shippingFee = 0, ?string $voucherId = null, bool $useKelopak = true): array
{
    $parsed = [];
    foreach ($lines as [$code, $price, $quantity]) {
        $parsed[] = ['productCode' => $code, 'unitPrice' => $price, 'quantity' => $quantity];
    }
    return ['lines' => $parsed, 'shippingFee' => $shippingFee, 'voucherId' => $voucherId, 'useKelopak' => $useKelopak];
}

// ------------------------------------------------------------ Aturan modul

$moduleCodes = [checkInSelfTest(), rodaSelfTest(), missionSelfTest()];
check('checkin.php swa-uji', $moduleCodes[0] === 0);
check('spin.php swa-uji', $moduleCodes[1] === 0);
check('missions.php swa-uji', $moduleCodes[2] === 0);

// ---------------------------------------------------------------- Kampanye

$campaignJson = json_decode((string) file_get_contents(__DIR__ . '/campaign.bpedia-demo.json'), true, 32, JSON_THROW_ON_ERROR);
$demo = kelopakCampaignFromArray($campaignJson);
check('kampanye demo: 2 tahap misi berjudul', array_column($demo['missionStages'], 'title') === ['Skincare Animate', 'Pinkflash & Focallure']);
check('kampanye demo: 4 produk roda', count($demo['wheelProductCodes']) === 4);
check('kampanye demo: promo 12.12 dari katalog server', $demo['promos'][0]['id'] === 'tanggal-kembar-1212' && $demo['promos'][0]['amount'] === 12000);
$claimDay1212 = kelopakOptionalWibDate('2026-12-12');
check('kampanye demo: hari klaim 12.12 WIB', $demo['promos'][0]['claimFromDay'] === $claimDay1212 && $demo['promos'][0]['claimUntilDay'] === $claimDay1212);
$rejected = 0;
foreach ([
    ['policy' => ['rupiahPerKelopak' => 0]],
    ['missionStages' => [['number' => 2, 'minOrderSubtotal' => 1, 'voucherAmount' => 1, 'voucherMinSpend' => 0, 'voucherValidDays' => 1]]],
    ['promos' => [['id' => 'x', 'title' => 'X', 'amount' => 0, 'minSpend' => 0, 'validDays' => 1]]],
    ['promos' => [['id' => 'x', 'title' => 'X', 'amount' => 1, 'minSpend' => 0, 'validDays' => 1, 'claimFrom' => '2026-02-30']]],
    ['prices' => ['P1' => -1]],
    ['wheelProductCodes' => ['']],
] as $bad) {
    try {
        kelopakCampaignFromArray($bad);
    } catch (InvalidArgumentException) {
        $rejected++;
    }
}
check('kampanye tidak sah ditolak', $rejected === 6);
$base = kelopakDemoCampaign();
check('kampanye bawaan = KelopakCampaign.demo', $base['wheelQuota'] === 3 && $base['missionStages'][0]['title'] === 'Tahap 1' && $base['wheel']['version'] === 'demo-v3-2026-11');

// --------------------------------------------------------------- Check-in

$day = 20783;
$state = kelopakEmptyState();
$result = kelopakCheckIn($state, $demo, $day);
check('check-in pertama', $result === ['claimed' => true, 'streak' => 1, 'dailyKelopak' => 1, 'bonusKelopak' => 0, 'productEntitled' => false, 'giftId' => null]);
check('check-in: saldo 1 dan catatan', kelopakBalance($state) === 1 && $state['ledger'][0]['id'] === 'L000001' && $state['ledger'][0]['note'] === 'Check-in hari ke-1');
check('check-in kedua di hari sama ditolak', kelopakCheckIn($state, $demo, $day) === ['claimed' => false]);
for ($d = $day + 1; $d < $day + 7; $d++) {
    $result = kelopakCheckIn($state, $demo, $d);
}
check('hari ke-7: bonus 3', $result['streak'] === 7 && $result['bonusKelopak'] === 3 && kelopakBalance($state) === 10);
check('bonus tercatat checkInBonus', end($state['ledger'])['kind'] === 'checkInBonus' && end($state['ledger'])['note'] === 'Bonus 7 hari beruntun');
for ($d = $day + 7; $d < $day + 30; $d++) {
    $result = kelopakCheckIn($state, $demo, $d);
}
check('hari ke-30: hadiah produk', $result['productEntitled'] === true && $result['giftId'] === 'HG-0001');
check('hadiah check-in memakai kode kampanye', $state['gifts'][0]['productCode'] === 'P39A06S01000089' && $state['gifts'][0]['source'] === 'checkIn30' && $state['gifts'][0]['status'] === 'pending');
$result = kelopakCheckIn($state, $demo, $day + 31);
check('bolong sehari: rentetan mulai 1', $result['streak'] === 1);

// ------------------------------------------------------------- Roda Sabtu

$saturday = saturdayFrom($day);
$state = kelopakEmptyState();
check('roda: bukan Sabtu', kelopakSpin($state, $demo, $saturday - 1, 0, 1) === ['spun' => false, 'reason' => 'notSaturday']);
$result = kelopakSpin($state, $demo, $saturday, 0, 77);
check('roda: roll 0 = produk', $result === ['spun' => true, 'wibDay' => $saturday] && $state['spins'][0]['prizeId'] === 'product');
check('roda: catatan putaran lengkap', $state['spins'][0]['productStockBefore'] === 3 && $state['spins'][0]['giftId'] === 'HG-0001' && $state['spins'][0]['landingSeed'] === 77 && $state['spins'][0]['configVersion'] === 'demo-v3-2026-11');
$expectedCode = $demo['wheelProductCodes'][kelopakWeekOf($saturday) % 4];
check('roda: produk bergilir per minggu', $state['gifts'][0]['productCode'] === $expectedCode && $state['gifts'][0]['source'] === 'wheel');
check('roda: kuota terpakai 1', kelopakWheelQuotaLeft($state, $demo, $saturday) === 2);
check('roda: satu putaran per Sabtu', kelopakSpin($state, $demo, $saturday, 0, 1) === ['spun' => false, 'reason' => 'alreadySpun']);
check('roda: kuota isi ulang tiap Senin', kelopakWheelQuotaLeft($state, $demo, $saturday + 2) === 3);
$state['promoActive'] = false;
check('roda: promo berhenti', kelopakSpin($state, $demo, $saturday + 7, 0, 1) === ['spun' => false, 'reason' => 'promoInactive']);
$state = kelopakEmptyState();
$state['wheelQuotaUsed'] = 3;
$state['wheelQuotaWeek'] = kelopakWeekOf($saturday);
kelopakSpin($state, $demo, $saturday, 0, 1);
check('roda: kuota habis, roll 0 bukan produk', $state['spins'][0]['prizeId'] !== 'product' && $state['gifts'] === [] && $state['spins'][0]['productStockBefore'] === 0);
check('roda: hadiah Kelopak masuk buku besar', end($state['ledger'])['kind'] === 'spinPrize' && str_starts_with(end($state['ledger'])['note'], 'Roda Sabtu: '));

// ---------------------------------------------------- Voucher promo (R1-10)

$state = kelopakEmptyState();
check('promo tak dikenal: invalidTerms', kelopakClaimPromo($state, $demo, 'promo-karangan', $claimDay1212) === ['claimed' => false, 'problem' => 'invalidTerms']);
check('promo sebelum hari klaim: invalidTerms', kelopakClaimPromo($state, $demo, 'tanggal-kembar-1212', $claimDay1212 - 1) === ['claimed' => false, 'problem' => 'invalidTerms']);
check('promo sesudah hari klaim: invalidTerms', kelopakClaimPromo($state, $demo, 'tanggal-kembar-1212', $claimDay1212 + 1) === ['claimed' => false, 'problem' => 'invalidTerms']);
$result = kelopakClaimPromo($state, $demo, 'tanggal-kembar-1212', $claimDay1212);
check('promo diklaim', $result === ['claimed' => true, 'voucherId' => 'VP-0001']);
check('nilai voucher promo dari katalog server', $state['vouchers'][0]['amount'] === 12000 && $state['vouchers'][0]['minSpend'] === 120000 && $state['vouchers'][0]['expiresDay'] === $claimDay1212 + 7 && $state['vouchers'][0]['title'] === 'Voucher Tanggal Kembar 12.12');
check('promo kedua kali: alreadyClaimed', kelopakClaimPromo($state, $demo, 'tanggal-kembar-1212', $claimDay1212) === ['claimed' => false, 'problem' => 'alreadyClaimed']);

// ------------------------------------------------------- Kutipan checkout

$state = kelopakEmptyState();
$quote = kelopakQuote($state, $demo, request([['P1', 26000, 2]], 12000), $day);
check('token kutipan = CheckoutQuote.token Dart', $quote['token'] === 'kq1|' . $day . '|P1*26000*2|12000|-|0|0||64000');
grant($state, 50, $day);
$quote = kelopakQuote($state, $demo, request([['P1', 3000, 1]], 9000), $day);
check('Kelopak maks. = harga barang (tidak melebihi)', $quote['kelopakUsed'] === 30 && $quote['kelopakValue'] === 3000 && $quote['total'] === 9000);
$quote = kelopakQuote($state, $demo, request([['P1', 3050, 1]]), $day);
check('pecahan < Rp100 tetap dibayar', $quote['kelopakUsed'] === 30 && $quote['total'] === 50);
$quote = kelopakQuote($state, $demo, request([['P1', 3000, 1]], 0, null, false), $day);
check('Kelopak tidak dipakai', $quote['kelopakUsed'] === 0 && $quote['kelopakMax'] === 30 && $quote['total'] === 3000);
$half = kelopakCampaignFromArray(['policy' => ['rupiahPerKelopak' => 100, 'redeemShareBp' => 5000]]);
$quote = kelopakQuote($state, $half, request([['P1', 6000, 1]]), $day);
check('redeemShareBp 50%', $quote['kelopakUsed'] === 30 && $quote['total'] === 3000);
$quote = kelopakQuote($state, $half, request([['P1', 2050, 1]]), $day);
check('redeemShareBp 50% dibulatkan ke bawah', $quote['kelopakUsed'] === 10);
kelopakAddGift($state, 'wheel', $day, 'P9');
$quote = kelopakQuote($state, $demo, request([]), $day);
check('tanpa barang berbayar: hadiah tidak ikut', $quote['giftIds'] === [] && $quote['waitingGiftCount'] === 1 && $quote['goodsSubtotal'] === 0);
$state['vouchers'][] = ['id' => 'VM-0009', 'kind' => 'mission', 'title' => 'V', 'amount' => 10000, 'minSpend' => 100000, 'issuedDay' => $day, 'expiresDay' => $day + 30, 'stageNumber' => 1, 'sourceOrderId' => 'BP-OLD', 'promoId' => null, 'usedOnOrderId' => null];
$quote = kelopakQuote($state, $demo, request([['P1', 50000, 1]], 0, 'VM-0009'), $day);
check('voucher di bawah minimum: belowMinimum, tidak dipotong', $quote['voucherProblem'] === 'belowMinimum' && $quote['voucherAmount'] === 0 && str_contains($quote['token'], '|-|0|'));
$quote = kelopakQuote($state, $demo, request([['P1', 100000, 1]], 10000, 'VM-0009'), $day);
check('urutan K16: voucher lalu Kelopak lalu ongkir', $quote['voucherAmount'] === 10000 && $quote['kelopakUsed'] === 50 && $quote['total'] === 100000 - 10000 - 5000 + 10000);
check('token memuat voucher dan hadiah', $quote['token'] === 'kq1|' . $day . '|P1*100000*1|10000|VM-0009|10000|50|HG-0001|95000');
$quote = kelopakQuote($state, $demo, request([['P1', 100000, 1]], 0, 'VM-0009'), $day + 31);
check('voucher kedaluwarsa', $quote['voucherProblem'] === 'expired');
$quote = kelopakQuote($state, $demo, request([['P1', 100000, 1]], 0, 'TIDAK-ADA'), $day);
check('voucher tak dikenal diabaikan seperti Dart', $quote['voucherId'] === null && $quote['voucherAmount'] === 0);

// ------------------------------------------------------- Pesanan lengkap

$state = kelopakEmptyState();
grant($state, 100, $day);
kelopakAddGift($state, 'checkIn30', $day, 'P39A06S01000089');
$state['vouchers'][] = ['id' => 'VP-0001', 'kind' => 'promo', 'title' => 'Voucher', 'amount' => 12000, 'minSpend' => 50000, 'issuedDay' => $day, 'expiresDay' => $day + 7, 'stageNumber' => null, 'sourceOrderId' => null, 'promoId' => 'p', 'usedOnOrderId' => null];
$state['voucherSeq'] = 1;
$order = request([['P39A06S01000021', 80000, 1]], 12000, 'VP-0001');
$quote = kelopakQuote($state, $demo, $order, $day);
check('komit: token basi ditolak', kelopakCommit($state, $demo, 'BP-1', $order, 'kq1|basi', $day) === ['committed' => false, 'problem' => 'quoteOutdated']);
check('komit: hari berganti = quoteOutdated', kelopakCommit($state, $demo, 'BP-1', $order, $quote['token'], $day + 1) === ['committed' => false, 'problem' => 'quoteOutdated']);
check('komit: tanpa barang berbayar', kelopakCommit($state, $demo, 'BP-0', request([]), 'x', $day) === ['committed' => false, 'problem' => 'noPaidItems']);
check('komit berhasil', kelopakCommit($state, $demo, 'BP-1', $order, $quote['token'], $day) === ['committed' => true, 'orderId' => 'BP-1']);
$placed = $state['orders'][0];
check('komit: pesanan tercatat', $placed['status'] === 'placed' && $placed['voucherId'] === 'VP-0001' && $placed['kelopakUsed'] === 100 && $placed['giftIds'] === ['HG-0001'] && $placed['total'] === 80000 - 12000 - 10000 + 12000);
check('komit: Kelopak, voucher, hadiah terpakai', kelopakBalance($state) === 0 && $state['vouchers'][0]['usedOnOrderId'] === 'BP-1' && $state['gifts'][0]['status'] === 'attached' && $state['gifts'][0]['orderId'] === 'BP-1');
$ledgerCount = count($state['ledger']);
check('komit ulang token sama: idempoten', kelopakCommit($state, $demo, 'BP-1', $order, $quote['token'], $day) === ['committed' => true, 'orderId' => 'BP-1'] && count($state['ledger']) === $ledgerCount && count($state['orders']) === 1);
check('komit ulang token beda: duplicateOrder', kelopakCommit($state, $demo, 'BP-1', $order, 'kq1|lain', $day) === ['committed' => false, 'problem' => 'duplicateOrder']);
$result = kelopakCancel($state, 'BP-1', $day + 1);
check('batal: semua kembali', $result === ['cancelled' => true, 'orderId' => 'BP-1', 'kelopakRefunded' => 100, 'voucherId' => 'VP-0001', 'giftIds' => ['HG-0001']]);
check('batal: saldo, voucher, hadiah pulih', kelopakBalance($state) === 100 && $state['vouchers'][0]['usedOnOrderId'] === null && $state['gifts'][0]['status'] === 'pending' && $state['gifts'][0]['orderId'] === null);
check('batal: status dan hari tutup', $state['orders'][0]['status'] === 'cancelled' && $state['orders'][0]['closedDay'] === $day + 1 && end($state['ledger'])['kind'] === 'checkoutRefund');
check('batal kedua kali: tidak ada', kelopakCancel($state, 'BP-1', $day + 1) === ['cancelled' => false]);
check('kirim pesanan batal: tidak ada', kelopakShip($state, 'BP-1') === ['shipped' => false]);
check('terima pesanan batal: tidak ada', kelopakComplete($state, $demo, 'BP-1', $day + 2) === ['completed' => false]);

$order = request([['P39A06S01000021', 50000, 1], ['P39A06S01000044', 30000, 1], ['LAIN', 90000, 1]]);
$quote = kelopakQuote($state, $demo, $order, $day + 2);
kelopakCommit($state, $demo, 'BP-2', $order, $quote['token'], $day + 2);
check('kirim', kelopakShip($state, 'BP-2') === ['shipped' => true, 'orderId' => 'BP-2'] && $state['gifts'][0]['status'] === 'shipped');
check('kirim dua kali: tidak ada', kelopakShip($state, 'BP-2') === ['shipped' => false]);
check('batal sesudah kirim: tidak bisa', kelopakCancel($state, 'BP-2', $day + 3) === ['cancelled' => false]);
$result = kelopakComplete($state, $demo, 'BP-2', $day + 4);
check('terima: tahap 1 tuntas, voucher misi terbit', $result === ['completed' => true, 'orderId' => 'BP-2', 'issuedStage' => 1, 'rejection' => null, 'voucherId' => 'VM-0002', 'giftIds' => ['HG-0001']]);
$missionVoucher = end($state['vouchers']);
check('voucher misi dari tahap kampanye', $missionVoucher['title'] === 'Voucher Misi Belanja Skincare Animate' && $missionVoucher['amount'] === 10000 && $missionVoucher['minSpend'] === 100000 && $missionVoucher['expiresDay'] === $day + 34 && $missionVoucher['sourceOrderId'] === 'BP-2');
check('terima: hadiah diterima, pesanan dihitung', $state['gifts'][0]['status'] === 'received' && $state['missionIssuedCount'] === 1 && $state['countedOrderIds'] === ['BP-2']);
check('terima dua kali: tidak ada', kelopakComplete($state, $demo, 'BP-2', $day + 4) === ['completed' => false]);
$order = request([['LAIN', 200000, 1], ['P21P03C01000082', 20000, 1]]);
$quote = kelopakQuote($state, $demo, $order, $day + 5);
kelopakCommit($state, $demo, 'BP-3', $order, $quote['token'], $day + 5);
$result = kelopakComplete($state, $demo, 'BP-3', $day + 6);
check('tahap 2: hanya produk misi dihitung (belowThreshold)', $result['issuedStage'] === null && $result['rejection'] === 'belowThreshold' && $state['missionIssuedCount'] === 1);
check('countedOrderIds terurut', $state['countedOrderIds'] === ['BP-2', 'BP-3']);

$priced = kelopakCampaignFromArray(['prices' => ['P1' => 26000]]);
$state = kelopakEmptyState();
$cheap = request([['P1', 1000, 1]]);
$quote = kelopakQuote($state, $priced, $cheap, $day);
check('katalog harga: harga dari klien dimanipulasi ditolak', kelopakCommit($state, $priced, 'BP-9', $cheap, $quote['token'], $day) === ['committed' => false, 'problem' => 'quoteOutdated']);
$fair = request([['P1', 26000, 1]]);
$quote = kelopakQuote($state, $priced, $fair, $day);
check('katalog harga: harga benar diterima', kelopakCommit($state, $priced, 'BP-9', $fair, $quote['token'], $day)['committed'] === true);
check('ringkasan hadiah', kelopakGiftSummary(['gifts' => [['id' => 'A', 'status' => 'pending'], ['id' => 'B', 'status' => 'received']]]) === ['pending' => ['A'], 'attached' => [], 'shipped' => [], 'received' => ['B']]);

// -------------------------------------------------------------------- HTTP

$store = new MemoryKelopakStore();
$token = 'sesi-uji-0123456789abcdef';
$auth = ['authorization' => 'Bearer ' . $token];
$json = ['content-type' => 'application/json'];
$demoOptions = ['now' => noonOf($day), 'demo' => true, 'serviceKey' => null, 'random' => fixedRandom([])];
$prodOptions = ['now' => noonOf($day), 'demo' => false, 'serviceKey' => 'kunci-layanan-rahasia', 'random' => fixedRandom([])];

$call = static function (string $method, string $path, ?array $body = null, array $headers = [], ?array $options = null) use (&$store, $demo, $demoOptions, $auth, $json): array {
    $response = kelopakHandleRequest(
        [
            'method' => $method,
            'path' => $path,
            'headers' => $headers + $auth + ($body === null ? [] : $json),
            'body' => $body === null ? '' : json_encode($body, JSON_THROW_ON_ERROR),
        ],
        $store,
        $demo,
        $options ?? $demoOptions,
    );
    $response['json'] = json_decode($response['body'], true);
    return $response;
};

$response = kelopakHandleRequest(['method' => 'GET', 'path' => '/kelopak/state', 'headers' => [], 'body' => ''], $store, $demo, $demoOptions);
$problem = json_decode($response['body'], true);
check('HTTP: tanpa token = 401 problem+json', $response['status'] === 401 && $response['headers']['WWW-Authenticate'] === 'Bearer' && str_starts_with($response['headers']['Content-Type'], 'application/problem+json'));
check('HTTP: bentuk problem RFC 9457', $problem['type'] === 'urn:bpedia:kelopak:problem:unauthorized' && $problem['status'] === 401 && $problem['code'] === 'unauthorized' && is_string($problem['title']) && is_string($problem['detail']));
$response = $call('GET', '/kelopak/state', null, ['authorization' => 'Bearer pendek']);
check('HTTP: token terlalu pendek = 401', $response['status'] === 401);
check('HTTP: jalur tak dikenal = 404', $call('GET', '/kelopak/tidak-ada')['status'] === 404);
$response = $call('GET', '/kelopak/check-in');
check('HTTP: metode salah = 405 + Allow', $response['status'] === 405 && $response['headers']['Allow'] === 'POST');
$response = $call('GET', '/api/v1/kelopak/state/');
check('HTTP: awalan jalur dan garis miring akhir', $response['status'] === 200);
check('HTTP: read pengguna baru = keadaan kosong tanpa result', $response['json'] === ['state' => kelopakEmptyState()] && $response['headers']['X-Kelopak-Revision'] === '0');
$response = kelopakHandleRequest(['method' => 'POST', 'path' => '/kelopak/check-in', 'headers' => $auth + ['content-type' => 'text/plain'], 'body' => '{}'], $store, $demo, $demoOptions);
check('HTTP: bukan JSON = 415', $response['status'] === 415);
$response = kelopakHandleRequest(['method' => 'POST', 'path' => '/kelopak/check-in', 'headers' => $auth + $json, 'body' => '{"today":'], $store, $demo, $demoOptions);
check('HTTP: JSON rusak = 400 invalidRequest', $response['status'] === 400 && json_decode($response['body'], true)['code'] === 'invalidRequest');
$response = kelopakHandleRequest(['method' => 'POST', 'path' => '/kelopak/check-in', 'headers' => $auth + $json, 'body' => '[1,2]'], $store, $demo, $demoOptions);
check('HTTP: badan daftar = 400', $response['status'] === 400);
$response = kelopakHandleRequest(['method' => 'POST', 'path' => '/kelopak/check-in', 'headers' => $auth + $json, 'body' => str_repeat(' ', KELOPAK_MAX_BODY_BYTES + 1)], $store, $demo, $demoOptions);
check('HTTP: badan terlalu besar = 413', $response['status'] === 413);
check('HTTP: today di luar rentang demo = 400', $call('POST', '/kelopak/check-in', ['today' => $day + 1000])['status'] === 400);

$response = $call('POST', '/kelopak/check-in', ['today' => $day], ['idempotency-key' => 'checkin-' . $day]);
check('HTTP: check-in', $response['status'] === 200 && $response['json']['result']['claimed'] === true && $response['json']['state']['streak'] === 1 && $response['headers']['X-Kelopak-Revision'] === '1');
$response = $call('POST', '/kelopak/check-in', ['today' => $day], ['idempotency-key' => 'checkin-' . $day]);
check('HTTP: Idempotency-Key sama = hasil diputar ulang', $response['status'] === 200 && $response['json']['result']['claimed'] === true && ($response['headers']['Idempotency-Replayed'] ?? '') === 'true');
check('HTTP: putar ulang tidak menambah saldo', kelopakBalance($response['json']['state']) === 1 && $response['headers']['X-Kelopak-Revision'] === '1');
$response = $call('POST', '/kelopak/check-in', ['today' => $day + 1], ['idempotency-key' => 'checkin-' . $day]);
check('HTTP: kunci sama, isi beda = 409', $response['status'] === 409 && $response['json']['code'] === 'idempotencyKeyReused');
check('HTTP: Idempotency-Key tidak sah = 400', $call('POST', '/kelopak/check-in', ['today' => $day], ['idempotency-key' => 'a b'])['status'] === 400);
$response = $call('POST', '/kelopak/check-in', ['today' => $day]);
check('HTTP: check-in ulang tanpa kunci = claimed false', $response['json']['result'] === ['claimed' => false]);

$response = $call('POST', '/kelopak/vouchers/promo', [
    'promoId' => 'tanggal-kembar-1212',
    'amount' => 99999999,
    'minSpend' => 0,
    'validDays' => 3650,
    'title' => 'Voucher karangan',
    'today' => $claimDay1212,
]);
$voucher = $response['json']['state']['vouchers'][0] ?? null;
check('HTTP R1-10: nilai voucher dari klien diabaikan', $response['json']['result'] === ['claimed' => true, 'voucherId' => 'VP-0001'] && $voucher['amount'] === 12000 && $voucher['minSpend'] === 120000 && $voucher['expiresDay'] === $claimDay1212 + 7 && $voucher['title'] === 'Voucher Tanggal Kembar 12.12');
check('HTTP: promoId wajib', $call('POST', '/kelopak/vouchers/promo', ['today' => $day])['status'] === 400);

$spinOptions = ['random' => fixedRandom([0, 4242])] + $demoOptions;
$response = $call('POST', '/kelopak/wheel/spin', ['today' => $saturday], [], $spinOptions);
check('HTTP: roda diundi server', $response['json']['result'] === ['spun' => true, 'wibDay' => $saturday] && end($response['json']['state']['spins'])['roll'] === 0 && end($response['json']['state']['spins'])['landingSeed'] === 4242);

$order = request([['P39A06S01000021', 80000, 1]], 12000);
$response = $call('POST', '/kelopak/orders/quote', ['request' => $order, 'today' => $saturday]);
$serverQuote = $response['json']['result'];
check('HTTP: kutipan server', $response['status'] === 200 && $serverQuote['goodsSubtotal'] === 80000 && $serverQuote['giftIds'] === ['HG-0001'] && str_starts_with($serverQuote['token'], 'kq1|' . $saturday . '|'));
$response = $call('POST', '/kelopak/orders/commit', ['orderId' => 'BP-H1', 'request' => $order, 'token' => $serverQuote['token'], 'today' => $saturday]);
check('HTTP: komit', $response['json']['result'] === ['committed' => true, 'orderId' => 'BP-H1']);
check('HTTP: komit butuh request', $call('POST', '/kelopak/orders/commit', ['orderId' => 'BP-H2', 'token' => 'x'])['status'] === 400);
check('HTTP: orderId tidak sah', $call('POST', '/kelopak/orders/cancel', ['orderId' => '../x'])['status'] === 400);
$response = $call('POST', '/kelopak/orders/ship', ['orderId' => 'BP-H1']);
check('HTTP demo: kirim dari app', $response['json']['result'] === ['shipped' => true, 'orderId' => 'BP-H1']);
$response = $call('GET', '/kelopak/gifts');
check('HTTP: ringkasan hadiah', $response['json']['result']['shipped'] === ['HG-0001']);
$response = $call('POST', '/kelopak/orders/complete', ['orderId' => 'BP-H1', 'today' => $saturday + 3]);
check('HTTP: terima + misi', $response['json']['result']['completed'] === true && $response['json']['result']['issuedStage'] === 1);
check('HTTP: pengguna lain terpisah', $call('GET', '/kelopak/state', null, ['authorization' => 'Bearer sesi-lain-0123456789abcdef'])['json']['state'] === kelopakEmptyState());

$response = $call('POST', '/kelopak/check-in', ['today' => $day + 5], [], $prodOptions);
check('HTTP produksi: today dari klien diabaikan', $response['json']['result'] === ['claimed' => false] && $response['json']['state']['lastClaimDay'] === $day);
$response = $call('POST', '/kelopak/orders/ship', ['orderId' => 'BP-H1'], [], $prodOptions);
check('HTTP produksi: kirim dari app ditolak 403', $response['status'] === 403 && $response['json']['code'] === 'forbidden');
$response = $call('POST', '/kelopak/orders/ship', ['orderId' => 'BP-H1'], ['x-kelopak-service-key' => 'kunci-salah'], $prodOptions);
check('HTTP produksi: kunci layanan salah ditolak', $response['status'] === 403);
$response = $call('POST', '/kelopak/orders/ship', ['orderId' => 'BP-H1'], ['x-kelopak-service-key' => 'kunci-layanan-rahasia'], $prodOptions);
check('HTTP produksi: kunci layanan benar diterima', $response['status'] === 200 && $response['json']['result'] === ['shipped' => false]);
$response = $call('POST', '/kelopak/orders/complete', ['orderId' => 'BP-H1'], ['x-kelopak-service-key' => 'x'], ['serviceKey' => null] + $prodOptions);
check('HTTP produksi: tanpa kunci terpasang, terima ditolak', $response['status'] === 403);

$failing = new class implements KelopakStore {
    public function transact(string $userId, Closure $work): mixed
    {
        throw new RuntimeException('disk penuh /rahasia/jalur');
    }
};
$logged = ini_set('error_log', PHP_OS_FAMILY === 'Windows' ? 'NUL' : '/dev/null');
$response = kelopakHandleRequest(['method' => 'GET', 'path' => '/kelopak/state', 'headers' => $auth, 'body' => ''], $failing, $demo, $demoOptions);
ini_set('error_log', $logged === false ? '' : $logged);
check('HTTP: galat internal = 500 tanpa bocor detail', $response['status'] === 500 && !str_contains($response['body'], 'rahasia'));

// ------------------------------------------------------------ Berkas data

$directory = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'kelopak-selftest-' . bin2hex(random_bytes(4));
$fileStore = new FileKelopakStore($directory);
$fileCall = static fn (array $body): array => kelopakHandleRequest(
    ['method' => 'POST', 'path' => '/kelopak/check-in', 'headers' => $auth + $json, 'body' => json_encode($body, JSON_THROW_ON_ERROR)],
    $fileStore,
    $demo,
    $demoOptions,
);
$fileCall(['today' => $day]);
$fileCall(['today' => $day + 1]);
$response = kelopakHandleRequest(['method' => 'GET', 'path' => '/kelopak/state', 'headers' => $auth, 'body' => ''], $fileStore, $demo, $demoOptions);
$saved = json_decode($response['body'], true);
check('berkas: keadaan bertahan antar permintaan', $saved['state']['streak'] === 2 && $response['headers']['X-Kelopak-Revision'] === '2');
check('berkas: folder data dijaga .htaccess', is_file($directory . DIRECTORY_SEPARATOR . '.htaccess'));
foreach (glob($directory . DIRECTORY_SEPARATOR . '{,.}*', GLOB_BRACE) ?: [] as $file) {
    if (is_file($file)) {
        unlink($file);
    }
}
rmdir($directory);

foreach ($failures as $name) {
    fwrite(STDOUT, 'GAGAL: ' . $name . PHP_EOL);
}
fwrite(STDOUT, sprintf('selftest.php: %d cek, %d gagal', $checks, count($failures)) . PHP_EOL);
exit($failures === [] ? 0 : 1);
