<?php
declare(strict_types=1);
require __DIR__.'/checkin.php';
require __DIR__.'/spin.php';
require __DIR__.'/missions.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

function reply(int $code, array $body): never {
    http_response_code($code);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    exit;
}
function dayNow(): int { return intdiv(time()+25200,86400); }
function snapshot(array $s): array {
    $s['day'] = dayNow() + $s['offset'];
    return $s;
}
function smallInt(array $body, string $name, int $max): int {
    $v = $body[$name] ?? null;
    if (!is_int($v) || $v < 0 || $v > $max) throw new DomainException('Parameter simulasi tidak valid.');
    return $v;
}
function ref(array $body): string {
    $v = $body['order'] ?? null;
    if (!is_string($v) || !preg_match('/^[a-zA-Z0-9-]{1,64}$/D',$v)) throw new DomainException('Referensi pesanan tidak valid.');
    return $v;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') reply(405,['error'=>'Gunakan POST.']);
$raw = file_get_contents('php://input',false,null,0,4097);
if (strlen($raw)>4096) reply(413,['error'=>'Permintaan terlalu besar.']);
$body = json_decode($raw,true);
if (!is_array($body)) reply(400,['error'=>'JSON tidak valid.']);
$action = $body['action'] ?? '';
$key = $_SERVER['HTTP_X_DEMO_SESSION'] ?? '';
if ($action !== 'open' && !preg_match('/^[a-f0-9]{32}$/D',$key)) reply(401,['error'=>'Kode sesi demo tidak valid.']);

try {
    // Sibling of public_html; persists across a web deployment.
    $dir = getenv('KELOPAK_DATA_DIR') ?: dirname(__DIR__,2).'/kelopak-demo-data';
    if (!is_dir($dir) && !mkdir($dir,0700,true) && !is_dir($dir)) throw new RuntimeException();
    $db = new PDO('sqlite:'.$dir.'/demo.sqlite', null, null, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
    $db->exec('PRAGMA busy_timeout=5000');
    $db->exec('CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, state TEXT NOT NULL, updated INTEGER NOT NULL)');
    $db->exec('BEGIN IMMEDIATE');
    if ($action === 'open') {
        $db->exec('DELETE FROM accounts WHERE updated < '.(time()-7*86400));
        if ((int)$db->query('SELECT COUNT(*) FROM accounts')->fetchColumn() >= 5000) {
            $db->exec('ROLLBACK'); reply(429,['error'=>'Demo penuh, coba kembali nanti.']);
        }
        $key = bin2hex(random_bytes(16));
        $s = ['balance'=>0,'streak'=>0,'lastDay'=>null,'products'=>0,'spinDay'=>null,
            'spinResult'=>'','stock'=>1,'vouchers'=>[],'offset'=>0,'start'=>dayNow(),'revision'=>0,'history'=>[]];
        $db->prepare('INSERT INTO accounts VALUES(?,?,?)')->execute([hash('sha256',$key),json_encode($s),time()]);
        $db->exec('COMMIT');
        reply(201,['session'=>$key,'state'=>snapshot($s)]);
    }
    $id = hash('sha256',$key);
    $q=$db->prepare('SELECT state FROM accounts WHERE id=? AND updated>=?');
    $q->execute([$id,time()-7*86400]);
    $row=$q->fetchColumn();
    if ($row === false) { $db->exec('ROLLBACK'); reply(401,['error'=>'Sesi demo kedaluwarsa atau kode salah.']); }
    $s=json_decode($row,true,512,JSON_THROW_ON_ERROR);
    $day=dayNow()+$s['offset'];
    if ($action !== 'read') {
        if (($body['revision'] ?? null) !== $s['revision'] || ($body['day'] ?? null) !== $day) {
            $db->exec('ROLLBACK'); reply(409,['error'=>'Progres berubah. Periksa hasil terbaru.','state'=>snapshot($s)]);
        }
        $tx = bin2hex(random_bytes(5));
        switch ($action) {
            case 'checkin': $label=claimDay($s,$day); break;
            case 'spin': $label=claimSpin($s,$day,random_int(0,99)); break;
            case 'order': $label=recordDemoOrder($s,smallInt($body,'subtotal',100000000),ref($body),true); break;
            case 'redeem': $label=useDemoVoucher($s,smallInt($body,'stage',1),smallInt($body,'subtotal',100000000),ref($body)); break;
            case 'advance':
                $step=smallInt($body,'step',7);
                if ($step<1 || $s['offset']+$step>365) throw new DomainException('Batas kalender simulasi tercapai.');
                $s['offset']+=$step; $label='Kalender demo maju '.$step.' hari'; break;
            default: throw new DomainException('Tindakan tidak dikenal.');
        }
        $s['revision']++;
        array_unshift($s['history'],['id'=>$tx,'day'=>$day,'label'=>$label]);
        $s['history']=array_slice($s['history'],0,24);
    }
    $db->prepare('UPDATE accounts SET state=?,updated=? WHERE id=?')->execute([json_encode($s),time(),$id]);
    $db->exec('COMMIT');
    reply(200,['state'=>snapshot($s)]);
} catch (DomainException $e) {
    if (isset($db)) $db->exec('ROLLBACK');
    reply(422,['error'=>$e->getMessage()]);
} catch (Throwable $e) {
    reply(503,['error'=>'Layanan demo sementara tidak tersedia. Coba muat ulang progres.']);
}
