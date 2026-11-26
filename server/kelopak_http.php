<?php
declare(strict_types=1);

/*
 * Lapisan HTTP server acuan Kelopak v3: rute KelopakAction, token sesi,
 * idempotensi, penyimpanan per pengguna, dan galat application/problem+json.
 * Kontrak lengkap: docs/BACKEND.md.
 *
 * kelopakHandleRequest() murni terhadap masukannya (permintaan, penyimpanan,
 * jam, dan sumber acak disuntikkan) sehingga swa-uji tidak butuh server web.
 */

require_once __DIR__ . '/kelopak.php';

const KELOPAK_MAX_BODY_BYTES = 65536;
const KELOPAK_IDEMPOTENCY_KEEP = 200;
const KELOPAK_DEMO_DAY_RANGE = 400;
const KELOPAK_PROBLEM_TYPE = 'urn:bpedia:kelopak:problem:';

/** Rute: "METODE /jalur" => aksi. Sama dengan enum KelopakAction (+ quote, gifts). */
const KELOPAK_ROUTES = [
    'GET /kelopak/state' => 'read',
    'GET /kelopak/gifts' => 'gifts',
    'POST /kelopak/check-in' => 'checkIn',
    'POST /kelopak/wheel/spin' => 'spin',
    'POST /kelopak/vouchers/promo' => 'claimPromo',
    'POST /kelopak/orders/quote' => 'quote',
    'POST /kelopak/orders/commit' => 'commit',
    'POST /kelopak/orders/cancel' => 'cancel',
    'POST /kelopak/orders/ship' => 'ship',
    'POST /kelopak/orders/complete' => 'complete',
];

/** Aksi yang hanya boleh dipanggil sistem pesanan (kunci layanan) di luar Mode Demo. */
const KELOPAK_SERVICE_ACTIONS = ['ship', 'complete'];

/** Aksi yang tidak mengubah keadaan. */
const KELOPAK_READ_ACTIONS = ['read', 'gifts', 'quote'];

/** Galat HTTP dengan badan problem+json. */
final class KelopakHttpException extends RuntimeException
{
    /** @param array<string, string> $headers */
    public function __construct(
        public readonly int $status,
        public readonly string $problemCode,
        string $detail,
        public readonly array $headers = [],
    ) {
        parent::__construct($detail);
    }
}

/**
 * Penyimpanan dokumen per pengguna: {schema, revision, state, idempotency}.
 * transact() menjalankan $work secara eksklusif untuk satu pengguna; $work
 * menerima dokumen (null bila belum ada) dan mengembalikan
 * ['document' => ?array, 'value' => mixed]; dokumen null = tidak ditulis.
 */
interface KelopakStore
{
    public function transact(string $userId, Closure $work): mixed;
}

/** Penyimpanan di memori, untuk swa-uji. */
final class MemoryKelopakStore implements KelopakStore
{
    /** @var array<string, array<string, mixed>> */
    public array $documents = [];

    public function transact(string $userId, Closure $work): mixed
    {
        $outcome = $work($this->documents[$userId] ?? null);
        if ($outcome['document'] !== null) {
            $this->documents[$userId] = $outcome['document'];
        }
        return $outcome['value'];
    }
}

/** Satu berkas JSON per pengguna dengan kunci flock; cukup untuk demo satu mesin. */
final class FileKelopakStore implements KelopakStore
{
    public function __construct(private readonly string $directory)
    {
    }

    public function transact(string $userId, Closure $work): mixed
    {
        if (!preg_match('/^[a-f0-9]{64}$/D', $userId)) {
            throw new InvalidArgumentException('userId harus hash heksadesimal 64 karakter.');
        }
        $this->prepareDirectory();
        $path = $this->directory . DIRECTORY_SEPARATOR . 'u-' . $userId . '.json';
        $handle = fopen($path, 'c+');
        if ($handle === false) {
            throw new RuntimeException('Berkas data tidak bisa dibuka.');
        }
        try {
            if (!flock($handle, LOCK_EX)) {
                throw new RuntimeException('Berkas data tidak bisa dikunci.');
            }
            $raw = stream_get_contents($handle);
            $document = null;
            if ($raw !== false && $raw !== '') {
                $decoded = json_decode($raw, true, 64, JSON_THROW_ON_ERROR);
                $document = is_array($decoded) ? $decoded : null;
            }
            $outcome = $work($document);
            if ($outcome['document'] !== null) {
                $json = json_encode($outcome['document'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
                ftruncate($handle, 0);
                rewind($handle);
                fwrite($handle, $json);
                fflush($handle);
            }
            return $outcome['value'];
        } finally {
            flock($handle, LOCK_UN);
            fclose($handle);
        }
    }

    private function prepareDirectory(): void
    {
        if (!is_dir($this->directory) && !mkdir($this->directory, 0700, true) && !is_dir($this->directory)) {
            throw new RuntimeException('Folder data tidak bisa dibuat.');
        }
        $guard = $this->directory . DIRECTORY_SEPARATOR . '.htaccess';
        if (!is_file($guard)) {
            file_put_contents($guard, "Require all denied\n");
        }
    }
}

/**
 * ID pengguna dari token sesi. Acuan demo: setiap token adalah akunnya
 * sendiri (hash). Produksi: ganti dengan verifikasi sesi milik app Bpedia
 * dan kembalikan ID pelanggan; jangan pernah memakai ID dari badan permintaan.
 */
function kelopakUserIdFromToken(string $token): string
{
    return hash('sha256', 'bpedia-kelopak-demo|' . $token);
}

/**
 * Menangani satu permintaan.
 *
 * @param array{method: string, path: string, headers: array<string, string>, body: string} $request
 *        header berhuruf kecil.
 * @param array{now: int, demo: bool, serviceKey: ?string, random: Closure(int, int): int} $options
 * @return array{status: int, headers: array<string, string>, body: string}
 */
function kelopakHandleRequest(array $request, KelopakStore $store, array $campaign, array $options): array
{
    try {
        $action = kelopakRoute($request['method'], $request['path']);
        $userId = kelopakUserIdFromToken(kelopakBearerToken($request['headers']));
        if (in_array($action, KELOPAK_SERVICE_ACTIONS, true) && !$options['demo']) {
            $key = $request['headers']['x-kelopak-service-key'] ?? '';
            if ($options['serviceKey'] === null || $options['serviceKey'] === '' || !hash_equals($options['serviceKey'], $key)) {
                throw new KelopakHttpException(403, 'forbidden', 'Aksi ini hanya untuk sistem pesanan (header X-Kelopak-Service-Key).');
            }
        }
        $body = $request['method'] === 'GET' ? [] : kelopakJsonBody($request['headers'], $request['body']);
        $idempotencyKey = kelopakIdempotencyKey($request['headers'], $action);
        $serverToday = CheckInEngine::wibDayOf($options['now']);
        $today = kelopakToday($body, $serverToday, $options['demo']);
        $input = kelopakActionInput($action, $body);
        $fingerprint = hash('sha256', $action . '|' . json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR));

        $outcome = $store->transact($userId, static function (?array $document) use (
            $action,
            $input,
            $campaign,
            $today,
            $options,
            $idempotencyKey,
            $fingerprint,
        ): array {
            $document ??= [
                'schema' => KELOPAK_DOCUMENT_SCHEMA,
                'revision' => 0,
                'state' => kelopakEmptyState(),
                'idempotency' => [],
            ];
            if (($document['schema'] ?? null) !== KELOPAK_DOCUMENT_SCHEMA) {
                throw new RuntimeException('Skema dokumen tidak dikenal.');
            }
            $state = kelopakNormalizeState($document['state']);
            $saved = $idempotencyKey === null ? null : ($document['idempotency'][$idempotencyKey] ?? null);
            if ($saved !== null) {
                if ($saved['action'] !== $action || $saved['fingerprint'] !== $fingerprint) {
                    throw new KelopakHttpException(409, 'idempotencyKeyReused', 'Idempotency-Key ini sudah dipakai untuk permintaan lain.');
                }
                return [
                    'document' => null,
                    'value' => ['state' => $state, 'result' => $saved['result'], 'revision' => $document['revision'], 'replayed' => true],
                ];
            }
            $before = json_encode($state, JSON_THROW_ON_ERROR);
            $result = kelopakApplyAction($action, $state, $campaign, $input, $today, $options['random']);
            $changed = json_encode($state, JSON_THROW_ON_ERROR) !== $before;
            $write = $changed || $idempotencyKey !== null;
            if ($changed) {
                $document['revision']++;
                $document['state'] = $state;
            }
            if ($idempotencyKey !== null) {
                $document['idempotency'][$idempotencyKey] = ['action' => $action, 'fingerprint' => $fingerprint, 'result' => $result];
                if (count($document['idempotency']) > KELOPAK_IDEMPOTENCY_KEEP) {
                    $document['idempotency'] = array_slice($document['idempotency'], -KELOPAK_IDEMPOTENCY_KEEP, null, true);
                }
            }
            return [
                'document' => $write ? $document : null,
                'value' => ['state' => $state, 'result' => $result, 'revision' => $document['revision'], 'replayed' => false],
            ];
        });

        $payload = ['state' => $outcome['state']];
        if ($outcome['result'] !== null) {
            $payload['result'] = $outcome['result'];
        }
        $headers = kelopakBaseHeaders('application/json; charset=utf-8');
        $headers['X-Kelopak-Revision'] = (string) $outcome['revision'];
        if ($outcome['replayed']) {
            $headers['Idempotency-Replayed'] = 'true';
        }
        return ['status' => 200, 'headers' => $headers, 'body' => kelopakEncode($payload)];
    } catch (KelopakHttpException $error) {
        return kelopakProblem($error->status, $error->problemCode, $error->getMessage(), $error->headers);
    } catch (KelopakRequestException $error) {
        return kelopakProblem(400, 'invalidRequest', $error->getMessage());
    } catch (Throwable $error) {
        error_log('kelopak: ' . $error::class . ': ' . $error->getMessage());
        return kelopakProblem(500, 'internal', 'Terjadi galat di server. Coba lagi sebentar.');
    }
}

function kelopakRoute(string $method, string $path): string
{
    $position = strpos($path, '/kelopak/');
    $route = $position === false ? '' : rtrim(substr($path, $position), '/');
    $action = KELOPAK_ROUTES[$method . ' ' . $route] ?? null;
    if ($action !== null) {
        return $action;
    }
    $allowed = [];
    foreach (array_keys(KELOPAK_ROUTES) as $key) {
        [$routeMethod, $routePath] = explode(' ', $key, 2);
        if ($routePath === $route) {
            $allowed[] = $routeMethod;
        }
    }
    if ($allowed !== []) {
        throw new KelopakHttpException(405, 'methodNotAllowed', 'Metode ' . $method . ' tidak didukung di jalur ini.', ['Allow' => implode(', ', $allowed)]);
    }
    throw new KelopakHttpException(404, 'notFound', 'Jalur tidak dikenal.');
}

/** @param array<string, string> $headers */
function kelopakBearerToken(array $headers): string
{
    $authorization = $headers['authorization'] ?? '';
    if (!preg_match('/^Bearer ([A-Za-z0-9._~+\/=-]{16,512})$/D', $authorization, $match)) {
        throw new KelopakHttpException(401, 'unauthorized', 'Butuh header Authorization: Bearer <token sesi>.', ['WWW-Authenticate' => 'Bearer']);
    }
    return $match[1];
}

/**
 * @param array<string, string> $headers
 * @return array<string, mixed>
 */
function kelopakJsonBody(array $headers, string $raw): array
{
    if (strlen($raw) > KELOPAK_MAX_BODY_BYTES) {
        throw new KelopakHttpException(413, 'payloadTooLarge', 'Badan permintaan maksimal ' . KELOPAK_MAX_BODY_BYTES . ' byte.');
    }
    if (trim($raw) === '') {
        return [];
    }
    $type = strtolower($headers['content-type'] ?? '');
    if (!str_starts_with($type, 'application/json')) {
        throw new KelopakHttpException(415, 'unsupportedMediaType', 'Content-Type harus application/json.');
    }
    try {
        $body = json_decode($raw, true, 32, JSON_THROW_ON_ERROR | JSON_BIGINT_AS_STRING);
    } catch (JsonException) {
        throw new KelopakRequestException('Badan permintaan bukan JSON yang sah.');
    }
    if (!is_array($body) || ($body !== [] && array_is_list($body))) {
        throw new KelopakRequestException('Badan permintaan harus objek JSON.');
    }
    return $body;
}

/** @param array<string, string> $headers */
function kelopakIdempotencyKey(array $headers, string $action): ?string
{
    $key = $headers['idempotency-key'] ?? null;
    if ($key === null || in_array($action, KELOPAK_READ_ACTIONS, true)) {
        return null;
    }
    if (!preg_match('/^[A-Za-z0-9_.:-]{8,128}$/D', $key)) {
        throw new KelopakRequestException('Idempotency-Key harus 8-128 karakter [A-Za-z0-9_.:-].');
    }
    return $key;
}

/**
 * Hari WIB yang dipakai. Produksi: selalu jam server. Mode Demo: `today` dari
 * klien diterima dalam rentang ±400 hari dari jam server (Mode Demo app
 * memajukan hari).
 *
 * @param array<string, mixed> $body
 */
function kelopakToday(array $body, int $serverToday, bool $demo): int
{
    if (!$demo || !array_key_exists('today', $body)) {
        return $serverToday;
    }
    $today = $body['today'];
    if (!is_int($today) || abs($today - $serverToday) > KELOPAK_DEMO_DAY_RANGE) {
        throw new KelopakRequestException('today harus hari WIB dalam ±' . KELOPAK_DEMO_DAY_RANGE . ' hari dari jam server.');
    }
    return $today;
}

/**
 * Parameter tiap aksi, divalidasi sebelum transaksi. claimPromo hanya
 * membaca promoId: amount, minSpend, validDays, dan title dari klien
 * diabaikan.
 *
 * @param array<string, mixed> $body
 * @return array<string, mixed>
 */
function kelopakActionInput(string $action, array $body): array
{
    return match ($action) {
        'read', 'gifts', 'checkIn', 'spin' => [],
        'claimPromo' => ['promoId' => kelopakIdField($body, 'promoId')],
        'quote' => ['request' => kelopakParseCheckoutRequest($body['request'] ?? null), 'orderId' => ''],
        'commit' => [
            'orderId' => kelopakIdField($body, 'orderId'),
            'request' => kelopakParseCheckoutRequest($body['request'] ?? null),
            'token' => kelopakTokenField($body),
        ],
        'cancel', 'ship', 'complete' => ['orderId' => kelopakIdField($body, 'orderId')],
    };
}

/** @param array<string, mixed> $body */
function kelopakIdField(array $body, string $name): string
{
    $value = $body[$name] ?? null;
    if (!is_string($value) || !preg_match('/^[A-Za-z0-9._:-]{1,64}$/D', $value)) {
        throw new KelopakRequestException($name . ' harus 1-64 karakter [A-Za-z0-9._:-].');
    }
    return $value;
}

/** @param array<string, mixed> $body */
function kelopakTokenField(array $body): string
{
    $token = $body['token'] ?? null;
    if (!is_string($token) || $token === '' || strlen($token) > 16384) {
        throw new KelopakRequestException('token kutipan tidak sah.');
    }
    return $token;
}

/**
 * Menjalankan aksi pada $state; mengembalikan `result` (null untuk read).
 *
 * @param array<string, mixed> $input
 * @param Closure(int, int): int $random
 */
function kelopakApplyAction(string $action, array &$state, array $campaign, array $input, int $today, Closure $random): ?array
{
    return match ($action) {
        'read' => null,
        'gifts' => kelopakGiftSummary($state),
        'checkIn' => kelopakCheckIn($state, $campaign, $today),
        'spin' => kelopakSpin($state, $campaign, $today, $random(0, RODA_TOTAL_WEIGHT - 1), $random(0, (1 << 31) - 1)),
        'claimPromo' => kelopakClaimPromo($state, $campaign, $input['promoId'], $today),
        'quote' => kelopakQuote($state, $campaign, $input['request'], $today, $input['orderId']),
        'commit' => kelopakCommit($state, $campaign, $input['orderId'], $input['request'], $input['token'], $today),
        'cancel' => kelopakCancel($state, $input['orderId'], $today),
        'ship' => kelopakShip($state, $input['orderId']),
        'complete' => kelopakComplete($state, $campaign, $input['orderId'], $today),
    };
}

/** @return array<string, string> */
function kelopakBaseHeaders(string $contentType): array
{
    return [
        'Content-Type' => $contentType,
        'Cache-Control' => 'no-store',
        'X-Content-Type-Options' => 'nosniff',
    ];
}

/**
 * Galat RFC 9457: {type, title, status, detail, code}.
 *
 * @param array<string, string> $extraHeaders
 * @return array{status: int, headers: array<string, string>, body: string}
 */
function kelopakProblem(int $status, string $code, string $detail, array $extraHeaders = []): array
{
    $titles = [
        400 => 'Permintaan tidak sah',
        401 => 'Butuh login',
        403 => 'Tidak diizinkan',
        404 => 'Tidak ditemukan',
        405 => 'Metode tidak didukung',
        409 => 'Konflik',
        413 => 'Permintaan terlalu besar',
        415 => 'Jenis isi tidak didukung',
        500 => 'Galat server',
    ];
    $headers = kelopakBaseHeaders('application/problem+json; charset=utf-8') + $extraHeaders;
    return [
        'status' => $status,
        'headers' => $headers,
        'body' => kelopakEncode([
            'type' => KELOPAK_PROBLEM_TYPE . $code,
            'title' => $titles[$status] ?? 'Galat',
            'status' => $status,
            'detail' => $detail,
            'code' => $code,
        ]),
    ];
}

function kelopakEncode(array $payload): string
{
    return json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
}
