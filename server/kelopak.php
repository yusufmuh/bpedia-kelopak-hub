<?php
declare(strict_types=1);

/*
 * Mesin Kelopak sisi server (acuan v3, PHP 8.2+), cermin KelopakEngine di
 * lib/src/domain/engine.dart dan computeCheckoutQuote di checkout.dart.
 *
 * Keadaan adalah array dengan bentuk persis KelopakState.toJson(), sehingga
 * balasan server bisa dibaca RemoteKelopakBackend tanpa terjemahan. Hasil
 * tiap aksi berbentuk encode*() di lib/src/backend/reply_codec.dart.
 *
 * Aturan modul dipakai ulang dari salinan identik repo modul:
 * checkin.php (bpedia-daily-checkin), spin.php (bpedia-roda-sabtu),
 * missions.php (bpedia-misi-belanja).
 *
 * Nilai voucher promo, tahap misi, hadiah roda, dan harga (bila katalog harga
 * diisi) selalu diambil dari kampanye server, tidak pernah dari permintaan.
 */

require_once __DIR__ . '/checkin.php';
require_once __DIR__ . '/spin.php';
require_once __DIR__ . '/missions.php';

const KELOPAK_DOCUMENT_SCHEMA = 1;
const KELOPAK_FULL_SHARE_BP = 10000;
const KELOPAK_MAX_LINES = 200;
const KELOPAK_MAX_QUANTITY = 10000;
const KELOPAK_MAX_RUPIAH = 1000000000;

/** Permintaan yang tidak sah (HTTP 400). */
final class KelopakRequestException extends InvalidArgumentException
{
}

// ------------------------------------------------------------------ Kampanye

/**
 * Kampanye bawaan, setara KelopakCampaign.demo di Dart.
 *
 * @return array<string, mixed>
 */
function kelopakDemoCampaign(): array
{
    $stages = [];
    foreach (MISSION_DEMO_STAGES as $stage) {
        $stage['title'] = 'Tahap ' . $stage['number'];
        $stages[] = $stage;
    }
    return [
        'policy' => ['rupiahPerKelopak' => 100, 'redeemShareBp' => KELOPAK_FULL_SHARE_BP],
        'wheel' => rodaDemoConfig(),
        'wheelQuota' => 3,
        'wheelQuotaRefillsWeekly' => true,
        'wheelProductCodes' => [],
        'checkIn30ProductCode' => null,
        'missionStages' => $stages,
        'promos' => [],
        'prices' => null,
    ];
}

/**
 * Kampanye dari JSON (lihat campaign.bpedia-demo.json); kunci yang tidak ada
 * memakai nilai kelopakDemoCampaign(). Melempar InvalidArgumentException
 * bila isinya tidak sah.
 *
 * @param array<string, mixed> $json
 * @return array<string, mixed>
 */
function kelopakCampaignFromArray(array $json): array
{
    $campaign = kelopakDemoCampaign();
    $fail = static function (string $what): never {
        throw new InvalidArgumentException('Kampanye tidak sah: ' . $what . '.');
    };

    if (isset($json['policy'])) {
        $policy = $json['policy'];
        $rate = $policy['rupiahPerKelopak'] ?? 100;
        $share = $policy['redeemShareBp'] ?? KELOPAK_FULL_SHARE_BP;
        if (!is_int($rate) || $rate < 1 || !is_int($share) || $share < 0 || $share > KELOPAK_FULL_SHARE_BP) {
            $fail('policy');
        }
        $campaign['policy'] = ['rupiahPerKelopak' => $rate, 'redeemShareBp' => $share];
    }
    if (isset($json['wheel'])) {
        if (!is_array($json['wheel']) || !is_string($json['wheel']['version'] ?? null)) {
            $fail('wheel');
        }
        rodaCheckConfig($json['wheel']);
        $campaign['wheel'] = $json['wheel'];
    }
    if (array_key_exists('wheelQuota', $json)) {
        if (!is_int($json['wheelQuota']) || $json['wheelQuota'] < 0) {
            $fail('wheelQuota');
        }
        $campaign['wheelQuota'] = $json['wheelQuota'];
    }
    if (array_key_exists('wheelQuotaRefillsWeekly', $json)) {
        if (!is_bool($json['wheelQuotaRefillsWeekly'])) {
            $fail('wheelQuotaRefillsWeekly');
        }
        $campaign['wheelQuotaRefillsWeekly'] = $json['wheelQuotaRefillsWeekly'];
    }
    if (array_key_exists('wheelProductCodes', $json)) {
        $campaign['wheelProductCodes'] = kelopakCodeList($json['wheelProductCodes']) ?? $fail('wheelProductCodes');
    }
    if (array_key_exists('checkIn30ProductCode', $json)) {
        $code = $json['checkIn30ProductCode'];
        if ($code !== null && (!is_string($code) || $code === '')) {
            $fail('checkIn30ProductCode');
        }
        $campaign['checkIn30ProductCode'] = $code;
    }
    if (array_key_exists('missionStages', $json)) {
        if (!is_array($json['missionStages']) || !array_is_list($json['missionStages'])) {
            $fail('missionStages');
        }
        $stages = [];
        foreach ($json['missionStages'] as $index => $stage) {
            $ints = ['minOrderSubtotal', 'voucherAmount', 'voucherMinSpend', 'voucherValidDays'];
            if (!is_array($stage) || ($stage['number'] ?? null) !== $index + 1) {
                $fail('missionStages[' . $index . '].number');
            }
            foreach ($ints as $key) {
                if (!is_int($stage[$key] ?? null) || $stage[$key] < 0) {
                    $fail('missionStages[' . $index . '].' . $key);
                }
            }
            if ($stage['voucherAmount'] < 1 || $stage['voucherValidDays'] < 1) {
                $fail('missionStages[' . $index . '] voucher');
            }
            $title = $stage['title'] ?? ('Tahap ' . $stage['number']);
            if (!is_string($title) || $title === '') {
                $fail('missionStages[' . $index . '].title');
            }
            $stages[] = [
                'number' => $stage['number'],
                'title' => $title,
                'minOrderSubtotal' => $stage['minOrderSubtotal'],
                'voucherAmount' => $stage['voucherAmount'],
                'voucherMinSpend' => $stage['voucherMinSpend'],
                'voucherValidDays' => $stage['voucherValidDays'],
                'productCodes' => kelopakCodeList($stage['productCodes'] ?? []) ?? $fail('missionStages[' . $index . '].productCodes'),
            ];
        }
        $campaign['missionStages'] = $stages;
    }
    if (array_key_exists('promos', $json)) {
        if (!is_array($json['promos']) || !array_is_list($json['promos'])) {
            $fail('promos');
        }
        $promos = [];
        foreach ($json['promos'] as $index => $promo) {
            $promos[] = kelopakPromoFromArray($promo) ?? $fail('promos[' . $index . ']');
        }
        $ids = array_column($promos, 'id');
        if (count(array_unique($ids)) !== count($ids)) {
            $fail('promos: id ganda');
        }
        $campaign['promos'] = $promos;
    }
    if (array_key_exists('prices', $json) && $json['prices'] !== null) {
        if (!is_array($json['prices']) || array_is_list($json['prices'])) {
            $fail('prices');
        }
        foreach ($json['prices'] as $code => $price) {
            if (!is_string($code) || $code === '' || !is_int($price) || $price < 0) {
                $fail('prices');
            }
        }
        $campaign['prices'] = $json['prices'];
    }
    return $campaign;
}

/**
 * Promo voucher server: id, judul, nilai, minimal belanja, masa berlaku, dan
 * jendela klaim (tanggal WIB Y-m-d, opsional).
 *
 * @return array{id: string, title: string, amount: int, minSpend: int, validDays: int, claimFromDay: ?int, claimUntilDay: ?int}|null
 */
function kelopakPromoFromArray(mixed $promo): ?array
{
    if (!is_array($promo)) {
        return null;
    }
    $id = $promo['id'] ?? null;
    $title = $promo['title'] ?? null;
    $amount = $promo['amount'] ?? null;
    $minSpend = $promo['minSpend'] ?? null;
    $validDays = $promo['validDays'] ?? null;
    if (!is_string($id) || $id === '' || !is_string($title) || $title === ''
        || !is_int($amount) || $amount < 1 || !is_int($minSpend) || $minSpend < 0
        || !is_int($validDays) || $validDays < 1) {
        return null;
    }
    $from = kelopakOptionalWibDate($promo['claimFrom'] ?? null);
    $until = kelopakOptionalWibDate($promo['claimUntil'] ?? null);
    if ($from === false || $until === false || ($from !== null && $until !== null && $until < $from)) {
        return null;
    }
    return [
        'id' => $id,
        'title' => $title,
        'amount' => $amount,
        'minSpend' => $minSpend,
        'validDays' => $validDays,
        'claimFromDay' => $from,
        'claimUntilDay' => $until,
    ];
}

/** Hari WIB dari tanggal "Y-m-d"; null bila kosong, false bila tidak sah. */
function kelopakOptionalWibDate(mixed $value): int|false|null
{
    if ($value === null) {
        return null;
    }
    if (!is_string($value) || !preg_match('/^(\d{4})-(\d{2})-(\d{2})$/D', $value, $m)
        || !checkdate((int) $m[2], (int) $m[3], (int) $m[1])) {
        return false;
    }
    return intdiv(gmmktime(0, 0, 0, (int) $m[2], (int) $m[3], (int) $m[1]), 86400);
}

/** @return list<string>|null */
function kelopakCodeList(mixed $codes): ?array
{
    if (!is_array($codes) || !array_is_list($codes)) {
        return null;
    }
    foreach ($codes as $code) {
        if (!is_string($code) || $code === '') {
            return null;
        }
    }
    return $codes;
}

/** Minggu kuota roda (Senin sebagai awal), sama dengan KelopakCampaign.weekOf. */
function kelopakWeekOf(int $wibDay): int
{
    return intdiv($wibDay + 3, 7);
}

/** Kode produk hadiah roda pada hari itu, sama dengan wheelProductCodeFor. */
function kelopakWheelProductCodeFor(array $campaign, array $prize, int $wibDay): ?string
{
    if ($prize['kind'] !== 'product') {
        return null;
    }
    $own = $prize['productCode'] ?? null;
    if (is_string($own) && $own !== '') {
        return $own;
    }
    $codes = $campaign['wheelProductCodes'];
    if ($codes === []) {
        return null;
    }
    return $codes[kelopakWeekOf($wibDay) % count($codes)];
}

// ------------------------------------------------------------------- Keadaan

/** @return array<string, mixed> KelopakState kosong. */
function kelopakEmptyState(): array
{
    return [
        'ledger' => [],
        'streak' => 0,
        'lastClaimDay' => null,
        'gifts' => [],
        'spins' => [],
        'promoActive' => true,
        'wheelQuotaUsed' => 0,
        'wheelQuotaWeek' => null,
        'missionIssuedCount' => 0,
        'countedOrderIds' => [],
        'vouchers' => [],
        'orders' => [],
        'ledgerSeq' => 0,
        'giftSeq' => 0,
        'voucherSeq' => 0,
    ];
}

/**
 * Keadaan tersimpan dengan kunci lengkap dan urutan baku.
 *
 * @param array<string, mixed> $state
 * @return array<string, mixed>
 */
function kelopakNormalizeState(array $state): array
{
    $normal = kelopakEmptyState();
    foreach ($normal as $key => $default) {
        if (array_key_exists($key, $state)) {
            $normal[$key] = is_array($default) ? array_values((array) $state[$key]) : $state[$key];
        }
    }
    $ids = $normal['countedOrderIds'];
    sort($ids, SORT_STRING);
    $normal['countedOrderIds'] = array_values(array_unique($ids));
    return $normal;
}

function kelopakBalance(array $state): int
{
    $total = 0;
    foreach ($state['ledger'] as $entry) {
        $total += $entry['amount'];
    }
    return $total;
}

function kelopakQuotaUsedOn(array $state, array $campaign, int $today): int
{
    return $campaign['wheelQuotaRefillsWeekly'] && $state['wheelQuotaWeek'] !== kelopakWeekOf($today)
        ? 0
        : $state['wheelQuotaUsed'];
}

function kelopakWheelQuotaLeft(array $state, array $campaign, int $today): int
{
    return max(0, $campaign['wheelQuota'] - kelopakQuotaUsedOn($state, $campaign, $today));
}

function kelopakAddLedger(array &$state, int $day, int $amount, string $kind, string $note, ?string $orderId = null): void
{
    $seq = $state['ledgerSeq'] + 1;
    $state['ledger'][] = [
        'id' => sprintf('L%06d', $seq),
        'wibDay' => $day,
        'amount' => $amount,
        'kind' => $kind,
        'note' => $note,
        'orderId' => $orderId,
    ];
    $state['ledgerSeq'] = $seq;
}

function kelopakAddGift(array &$state, string $source, int $day, ?string $productCode): string
{
    $seq = $state['giftSeq'] + 1;
    $id = sprintf('HG-%04d', $seq);
    $state['gifts'][] = [
        'id' => $id,
        'source' => $source,
        'wonDay' => $day,
        'productCode' => $productCode,
        'status' => 'pending',
        'orderId' => null,
    ];
    $state['giftSeq'] = $seq;
    return $id;
}

function kelopakFindIndex(array $items, string $id): ?int
{
    foreach ($items as $index => $item) {
        if ($item['id'] === $id) {
            return $index;
        }
    }
    return null;
}

/**
 * Masalah pemakaian voucher (alreadyUsed, expired, sameOrder, belowMinimum)
 * atau null; voucher promo tidak punya pesanan sumber.
 */
function kelopakVoucherProblem(array $voucher, string $orderId, int $subtotal, int $today): ?string
{
    $redeem = $voucher;
    $redeem['sourceOrderId'] = $voucher['sourceOrderId'] ?? ('promo:' . ($voucher['promoId'] ?? $voucher['id']));
    return missionRedeemProblem($redeem, $orderId, $subtotal, $today);
}

// --------------------------------------------------------------------- Aksi

/** Klaim Check-in Harian; hasil = encodeCheckInOutcome. */
function kelopakCheckIn(array &$state, array $campaign, int $today): array
{
    $award = CheckInEngine::evaluate($today, $state['lastClaimDay'], $state['streak']);
    if ($award === null) {
        return ['claimed' => false];
    }
    kelopakAddLedger($state, $today, $award['dailyKelopak'], 'checkIn', 'Check-in hari ke-' . $award['streak']);
    if ($award['bonusKelopak'] > 0) {
        kelopakAddLedger($state, $today, $award['bonusKelopak'], 'checkInBonus', 'Bonus ' . $award['streak'] . ' hari beruntun');
    }
    $giftId = null;
    if ($award['productEntitled']) {
        $giftId = kelopakAddGift($state, 'checkIn30', $today, $campaign['checkIn30ProductCode']);
    }
    $state['streak'] = $award['streak'];
    $state['lastClaimDay'] = $today;
    return [
        'claimed' => true,
        'streak' => $award['streak'],
        'dailyKelopak' => $award['dailyKelopak'],
        'bonusKelopak' => $award['bonusKelopak'],
        'productEntitled' => $award['productEntitled'],
        'giftId' => $giftId,
    ];
}

/** Memutar Roda Sabtu dengan undian server; hasil = encodeSpinOutcome. */
function kelopakSpin(array &$state, array $campaign, int $today, int $roll, int $landingSeed): array
{
    $spins = $state['spins'];
    $lastSpinDay = $spins === [] ? null : $spins[count($spins) - 1]['wibDay'];
    $eligibility = rodaSpinEligibility($today, $lastSpinDay, $state['promoActive']);
    if ($eligibility !== 'available') {
        return ['spun' => false, 'reason' => $eligibility];
    }
    $stock = kelopakWheelQuotaLeft($state, $campaign, $today);
    $prize = rodaResolveSpin($campaign['wheel'], $stock, $roll);
    $giftId = null;
    if ($prize['kind'] === 'product') {
        $used = kelopakQuotaUsedOn($state, $campaign, $today);
        $giftId = kelopakAddGift($state, 'wheel', $today, kelopakWheelProductCodeFor($campaign, $prize, $today));
        $state['wheelQuotaUsed'] = $used + 1;
        $state['wheelQuotaWeek'] = kelopakWeekOf($today);
    } elseif ((int) $prize['kelopak'] > 0) {
        kelopakAddLedger($state, $today, (int) $prize['kelopak'], 'spinPrize', 'Roda Sabtu: ' . $prize['label']);
    }
    $state['spins'][] = [
        'wibDay' => $today,
        'prizeId' => $prize['id'],
        'roll' => $roll,
        'landingSeed' => $landingSeed,
        'configVersion' => $campaign['wheel']['version'],
        'productStockBefore' => $stock,
        'giftId' => $giftId,
    ];
    return ['spun' => true, 'wibDay' => $today];
}

/**
 * Klaim voucher promo $promoId sekali per pengguna. Nilai, minimal belanja,
 * masa berlaku, dan judul diambil dari katalog promo kampanye; hasil =
 * encodePromoClaimOutcome.
 */
function kelopakClaimPromo(array &$state, array $campaign, string $promoId, int $today): array
{
    $promo = null;
    foreach ($campaign['promos'] as $candidate) {
        if ($candidate['id'] === $promoId) {
            $promo = $candidate;
        }
    }
    if ($promo === null) {
        return ['claimed' => false, 'problem' => 'invalidTerms'];
    }
    foreach ($state['vouchers'] as $voucher) {
        if (($voucher['promoId'] ?? null) === $promoId) {
            return ['claimed' => false, 'problem' => 'alreadyClaimed'];
        }
    }
    if (($promo['claimFromDay'] !== null && $today < $promo['claimFromDay'])
        || ($promo['claimUntilDay'] !== null && $today > $promo['claimUntilDay'])) {
        return ['claimed' => false, 'problem' => 'invalidTerms'];
    }
    $seq = $state['voucherSeq'] + 1;
    $id = sprintf('VP-%04d', $seq);
    $state['vouchers'][] = [
        'id' => $id,
        'kind' => 'promo',
        'title' => $promo['title'],
        'amount' => $promo['amount'],
        'minSpend' => $promo['minSpend'],
        'issuedDay' => $today,
        'expiresDay' => $today + $promo['validDays'],
        'stageNumber' => null,
        'sourceOrderId' => null,
        'promoId' => $promoId,
        'usedOnOrderId' => null,
    ];
    $state['voucherSeq'] = $seq;
    return ['claimed' => true, 'voucherId' => $id];
}

/**
 * CheckoutRequest.fromJson: {lines: [{productCode, unitPrice, quantity}],
 * shippingFee, voucherId, useKelopak}.
 *
 * @return array{lines: list<array{productCode: string, unitPrice: int, quantity: int}>, shippingFee: int, voucherId: ?string, useKelopak: bool}
 */
function kelopakParseCheckoutRequest(mixed $json): array
{
    if (!is_array($json) || ($json !== [] && array_is_list($json))) {
        throw new KelopakRequestException('request harus objek CheckoutRequest.');
    }
    $lines = $json['lines'] ?? null;
    if (!is_array($lines) || !array_is_list($lines) || count($lines) > KELOPAK_MAX_LINES) {
        throw new KelopakRequestException('request.lines harus daftar berisi paling banyak ' . KELOPAK_MAX_LINES . ' baris.');
    }
    $parsed = [];
    foreach ($lines as $index => $line) {
        $code = is_array($line) ? ($line['productCode'] ?? null) : null;
        $price = is_array($line) ? ($line['unitPrice'] ?? null) : null;
        $quantity = is_array($line) ? ($line['quantity'] ?? null) : null;
        if (!is_string($code) || $code === '' || strlen($code) > 64
            || !is_int($price) || $price < 0 || $price > KELOPAK_MAX_RUPIAH
            || !is_int($quantity) || $quantity < 1 || $quantity > KELOPAK_MAX_QUANTITY) {
            throw new KelopakRequestException('request.lines[' . $index . '] tidak sah.');
        }
        $parsed[] = ['productCode' => $code, 'unitPrice' => $price, 'quantity' => $quantity];
    }
    $fee = $json['shippingFee'] ?? 0;
    if (!is_int($fee) || $fee < 0 || $fee > KELOPAK_MAX_RUPIAH) {
        throw new KelopakRequestException('request.shippingFee tidak sah.');
    }
    $voucherId = $json['voucherId'] ?? null;
    if ($voucherId !== null && !is_string($voucherId)) {
        throw new KelopakRequestException('request.voucherId tidak sah.');
    }
    $useKelopak = $json['useKelopak'] ?? true;
    if (!is_bool($useKelopak)) {
        throw new KelopakRequestException('request.useKelopak tidak sah.');
    }
    return ['lines' => $parsed, 'shippingFee' => $fee, 'voucherId' => $voucherId, 'useKelopak' => $useKelopak];
}

/**
 * Kutipan checkout K16, setara computeCheckoutQuote: subtotal barang ->
 * voucher -> Kelopak (maks. redeemShareBp dari barang setelah voucher, per
 * Kelopak ke bawah, tidak melebihi saldo) -> + ongkir. `token` sama persis
 * dengan CheckoutQuote.token di Dart.
 *
 * @return array<string, mixed>
 */
function kelopakQuote(array $state, array $campaign, array $request, int $today, string $orderId = ''): array
{
    $goods = 0;
    foreach ($request['lines'] as $line) {
        $goods += $line['unitPrice'] > 0 && $line['quantity'] > 0 ? $line['unitPrice'] * $line['quantity'] : 0;
    }
    $voucher = null;
    if ($request['voucherId'] !== null) {
        $index = kelopakFindIndex($state['vouchers'], $request['voucherId']);
        $voucher = $index === null ? null : $state['vouchers'][$index];
    }
    $voucherProblem = null;
    $voucherAmount = 0;
    if ($voucher !== null) {
        $voucherProblem = kelopakVoucherProblem($voucher, $orderId, $goods, $today);
        if ($voucherProblem === null) {
            $voucherAmount = min($voucher['amount'], $goods);
        }
    }
    $afterVoucher = $goods - $voucherAmount;
    $policy = $campaign['policy'];
    $cap = $afterVoucher <= 0
        ? 0
        : intdiv(intdiv($afterVoucher * $policy['redeemShareBp'], KELOPAK_FULL_SHARE_BP), $policy['rupiahPerKelopak']);
    $balance = max(0, kelopakBalance($state));
    $kelopakMax = min($cap, $balance);
    $kelopakUsed = $request['useKelopak'] ? $kelopakMax : 0;
    $kelopakValue = $kelopakUsed * $policy['rupiahPerKelopak'];
    $waiting = [];
    foreach ($state['gifts'] as $gift) {
        if ($gift['status'] === 'pending') {
            $waiting[] = $gift['id'];
        }
    }
    $giftIds = $goods > 0 ? $waiting : [];
    $total = $afterVoucher - $kelopakValue + $request['shippingFee'];
    $voucherId = $voucher === null ? null : $voucher['id'];
    $applied = $voucherId !== null && $voucherProblem === null;
    $lineTokens = [];
    foreach ($request['lines'] as $line) {
        $lineTokens[] = $line['productCode'] . '*' . $line['unitPrice'] . '*' . $line['quantity'];
    }
    $token = 'kq1|' . $today . '|' . implode(',', $lineTokens) . '|' . $request['shippingFee'] . '|'
        . ($applied ? $voucherId : '-') . '|' . $voucherAmount . '|'
        . $kelopakUsed . '|' . implode(',', $giftIds) . '|' . $total;
    return [
        'day' => $today,
        'goodsSubtotal' => $goods,
        'shippingFee' => $request['shippingFee'],
        'voucherId' => $voucherId,
        'voucherApplied' => $applied,
        'voucherAmount' => $voucherAmount,
        'voucherProblem' => $voucherProblem,
        'kelopakBalance' => $balance,
        'kelopakMax' => $kelopakMax,
        'kelopakUsed' => $kelopakUsed,
        'kelopakValue' => $kelopakValue,
        'giftIds' => $giftIds,
        'waitingGiftCount' => count($waiting),
        'total' => $total,
        'token' => $token,
    ];
}

/** True bila katalog harga kampanye kosong atau semua harga baris cocok. */
function kelopakPricesMatch(array $campaign, array $request): bool
{
    $prices = $campaign['prices'];
    if ($prices === null) {
        return true;
    }
    foreach ($request['lines'] as $line) {
        if (($prices[$line['productCode']] ?? null) !== $line['unitPrice']) {
            return false;
        }
    }
    return true;
}

/**
 * Komit pesanan; idempoten per orderId + token. Hasil = encodeCommitOutcome.
 */
function kelopakCommit(array &$state, array $campaign, string $orderId, array $request, string $token, int $today): array
{
    $existing = kelopakFindIndex($state['orders'], $orderId);
    if ($existing !== null) {
        return $state['orders'][$existing]['quoteToken'] === $token
            ? ['committed' => true, 'orderId' => $orderId]
            : ['committed' => false, 'problem' => 'duplicateOrder'];
    }
    $quote = kelopakQuote($state, $campaign, $request, $today, $orderId);
    if ($quote['goodsSubtotal'] <= 0) {
        return ['committed' => false, 'problem' => 'noPaidItems'];
    }
    if (!kelopakPricesMatch($campaign, $request) || $quote['token'] !== $token) {
        return ['committed' => false, 'problem' => 'quoteOutdated'];
    }
    $voucherId = $quote['voucherApplied'] ? $quote['voucherId'] : null;
    if ($voucherId !== null) {
        $index = kelopakFindIndex($state['vouchers'], $voucherId);
        $state['vouchers'][$index]['usedOnOrderId'] = $orderId;
    }
    if ($quote['kelopakUsed'] > 0) {
        kelopakAddLedger($state, $today, -$quote['kelopakUsed'], 'checkoutSpend', 'Dipakai di pesanan ' . $orderId, $orderId);
    }
    foreach ($state['gifts'] as $index => $gift) {
        if (in_array($gift['id'], $quote['giftIds'], true)) {
            $state['gifts'][$index]['status'] = 'attached';
            $state['gifts'][$index]['orderId'] = $orderId;
        }
    }
    $state['orders'][] = [
        'id' => $orderId,
        'placedDay' => $today,
        'lines' => $request['lines'],
        'goodsSubtotal' => $quote['goodsSubtotal'],
        'shippingFee' => $quote['shippingFee'],
        'voucherId' => $voucherId,
        'voucherAmount' => $quote['voucherAmount'],
        'kelopakUsed' => $quote['kelopakUsed'],
        'kelopakValue' => $quote['kelopakValue'],
        'giftIds' => $quote['giftIds'],
        'total' => $quote['total'],
        'quoteToken' => $quote['token'],
        'status' => 'placed',
        'closedDay' => null,
    ];
    return ['committed' => true, 'orderId' => $orderId];
}

/** Batal pesanan yang belum dikirim; hasil = encodeCancellation. */
function kelopakCancel(array &$state, string $orderId, int $today): array
{
    $index = kelopakFindIndex($state['orders'], $orderId);
    if ($index === null || $state['orders'][$index]['status'] !== 'placed') {
        return ['cancelled' => false];
    }
    $order = $state['orders'][$index];
    if ($order['kelopakUsed'] > 0) {
        kelopakAddLedger($state, $today, $order['kelopakUsed'], 'checkoutRefund', 'Dikembalikan dari pesanan ' . $orderId, $orderId);
    }
    $released = null;
    if ($order['voucherId'] !== null) {
        $voucherIndex = kelopakFindIndex($state['vouchers'], $order['voucherId']);
        if ($voucherIndex !== null && $state['vouchers'][$voucherIndex]['usedOnOrderId'] === $orderId) {
            $state['vouchers'][$voucherIndex]['usedOnOrderId'] = null;
            $released = $order['voucherId'];
        }
    }
    $returned = [];
    foreach ($state['gifts'] as $giftIndex => $gift) {
        if ($gift['orderId'] === $orderId) {
            $state['gifts'][$giftIndex]['status'] = 'pending';
            $state['gifts'][$giftIndex]['orderId'] = null;
            $returned[] = $gift['id'];
        }
    }
    $state['orders'][$index]['status'] = 'cancelled';
    $state['orders'][$index]['closedDay'] = $today;
    return [
        'cancelled' => true,
        'orderId' => $orderId,
        'kelopakRefunded' => $order['kelopakUsed'],
        'voucherId' => $released,
        'giftIds' => $returned,
    ];
}

/** Pesanan dikirim (hadiah ikut dikirim); hasil = encodeShipment. */
function kelopakShip(array &$state, string $orderId): array
{
    $index = kelopakFindIndex($state['orders'], $orderId);
    if ($index === null || $state['orders'][$index]['status'] !== 'placed') {
        return ['shipped' => false];
    }
    kelopakSetGiftStatus($state, $orderId, 'shipped');
    $state['orders'][$index]['status'] = 'shipped';
    return ['shipped' => true, 'orderId' => $orderId];
}

/**
 * Pesanan diterima: hadiah diterima, lalu Misi Belanja menilai subtotal
 * produk misi pesanan ini; hasil = encodeCompletion.
 */
function kelopakComplete(array &$state, array $campaign, string $orderId, int $today): array
{
    $index = kelopakFindIndex($state['orders'], $orderId);
    if ($index === null || !in_array($state['orders'][$index]['status'], ['placed', 'shipped'], true)) {
        return ['completed' => false];
    }
    $order = $state['orders'][$index];
    kelopakSetGiftStatus($state, $orderId, 'received');
    $state['orders'][$index]['status'] = 'completed';
    $state['orders'][$index]['closedDay'] = $today;
    $lines = [];
    foreach ($order['lines'] as $line) {
        $lines[] = [
            'productCode' => $line['productCode'],
            'unitPrice' => max(0, $line['unitPrice']),
            'quantity' => max(0, $line['quantity']),
        ];
    }
    $decision = missionEvaluateOrderLines(
        $campaign['missionStages'],
        $state['missionIssuedCount'],
        $state['countedOrderIds'],
        $orderId,
        $lines,
        true,
    );
    if (!in_array($orderId, $state['countedOrderIds'], true)) {
        $state['countedOrderIds'][] = $orderId;
        sort($state['countedOrderIds'], SORT_STRING);
    }
    $voucherId = null;
    $stage = $decision['issuedStage'];
    if ($stage !== null) {
        $seq = $state['voucherSeq'] + 1;
        $voucherId = sprintf('VM-%04d', $seq);
        $state['vouchers'][] = [
            'id' => $voucherId,
            'kind' => 'mission',
            'title' => 'Voucher Misi Belanja ' . missionStageTitle($stage),
            'amount' => $stage['voucherAmount'],
            'minSpend' => $stage['voucherMinSpend'],
            'issuedDay' => $today,
            'expiresDay' => $today + $stage['voucherValidDays'],
            'stageNumber' => $stage['number'],
            'sourceOrderId' => $orderId,
            'promoId' => null,
            'usedOnOrderId' => null,
        ];
        $state['voucherSeq'] = $seq;
        $state['missionIssuedCount']++;
    }
    $giftIds = [];
    foreach ($state['gifts'] as $gift) {
        if ($gift['orderId'] === $orderId) {
            $giftIds[] = $gift['id'];
        }
    }
    return [
        'completed' => true,
        'orderId' => $orderId,
        'issuedStage' => $stage === null ? null : $stage['number'],
        'rejection' => $decision['rejection'],
        'voucherId' => $voucherId,
        'giftIds' => $giftIds,
    ];
}

function kelopakSetGiftStatus(array &$state, string $orderId, string $status): void
{
    foreach ($state['gifts'] as $index => $gift) {
        if ($gift['orderId'] === $orderId) {
            $state['gifts'][$index]['status'] = $status;
        }
    }
}

/** Ringkasan hadiah produk per status (aksi `gifts`). */
function kelopakGiftSummary(array $state): array
{
    $summary = ['pending' => [], 'attached' => [], 'shipped' => [], 'received' => []];
    foreach ($state['gifts'] as $gift) {
        $summary[$gift['status']][] = $gift['id'];
    }
    return $summary;
}
