<?php
declare(strict_types=1);

/*
 * Server acuan Kelopak v3 (PHP 8.2+): front controller HTTP untuk kontrak
 * RemoteKelopakBackend / KelopakAction. Kontrak dan cara pasang:
 * docs/BACKEND.md.
 *
 * Coba lokal:  BPEDIA_KELOPAK_DEMO=1 php -S 127.0.0.1:8787 server/index.php
 * Swa-uji:     php server/selftest.php
 *
 * Lingkungan:
 *   BPEDIA_KELOPAK_CAMPAIGN     berkas kampanye JSON (bawaan campaign.bpedia-demo.json)
 *   BPEDIA_KELOPAK_DATA         folder data per pengguna (bawaan server/data, di luar git)
 *   BPEDIA_KELOPAK_DEMO=1       Mode Demo: `today` dari klien diterima, ship/complete dari app
 *   BPEDIA_KELOPAK_SERVICE_KEY  kunci sistem pesanan untuk ship/complete di luar Mode Demo
 */

require_once __DIR__ . '/kelopak_http.php';

/** @return array<string, string> header berhuruf kecil */
function kelopakIncomingHeaders(): array
{
    $headers = [];
    foreach ($_SERVER as $name => $value) {
        if (is_string($value) && str_starts_with($name, 'HTTP_')) {
            $headers[strtolower(str_replace('_', '-', substr($name, 5)))] = $value;
        }
    }
    foreach (['CONTENT_TYPE' => 'content-type', 'REDIRECT_HTTP_AUTHORIZATION' => 'authorization'] as $name => $header) {
        if (!isset($headers[$header]) && is_string($_SERVER[$name] ?? null)) {
            $headers[$header] = $_SERVER[$name];
        }
    }
    return $headers;
}

function kelopakSend(array $response): void
{
    http_response_code($response['status']);
    foreach ($response['headers'] as $name => $value) {
        header($name . ': ' . $value);
    }
    echo $response['body'];
}

try {
    $campaignPath = getenv('BPEDIA_KELOPAK_CAMPAIGN') ?: __DIR__ . '/campaign.bpedia-demo.json';
    $campaignJson = json_decode((string) file_get_contents($campaignPath), true, 32, JSON_THROW_ON_ERROR);
    $campaign = kelopakCampaignFromArray(is_array($campaignJson) ? $campaignJson : []);
} catch (Throwable $error) {
    error_log('kelopak: kampanye tidak bisa dimuat: ' . $error->getMessage());
    kelopakSend(kelopakProblem(500, 'internal', 'Konfigurasi kampanye server tidak sah.'));
    return;
}

$path = $_SERVER['PATH_INFO'] ?? parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
$raw = file_get_contents('php://input', false, null, 0, KELOPAK_MAX_BODY_BYTES + 1);

kelopakSend(kelopakHandleRequest(
    [
        'method' => strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET')),
        'path' => is_string($path) ? $path : '/',
        'headers' => kelopakIncomingHeaders(),
        'body' => $raw === false ? '' : $raw,
    ],
    new FileKelopakStore(getenv('BPEDIA_KELOPAK_DATA') ?: __DIR__ . DIRECTORY_SEPARATOR . 'data'),
    $campaign,
    [
        'now' => time(),
        'demo' => getenv('BPEDIA_KELOPAK_DEMO') === '1',
        'serviceKey' => getenv('BPEDIA_KELOPAK_SERVICE_KEY') ?: null,
        'random' => random_int(...),
    ],
));
