<?php
declare(strict_types=1);

function claimDay(array &$state, int $today): string {
    $last = $state['lastDay'];
    if ($last !== null && $last >= $today) {
        throw new DomainException('Check-in hari ini sudah tercatat.');
    }
    $streak = $last === $today - 1 ? $state['streak'] + 1 : 1;
    $award = 1 + ($streak % 7 === 0 ? 3 : 0);
    $state['streak'] = $streak;
    $state['lastDay'] = $today;
    $state['balance'] += $award;
    $product = $streak % 30 === 0;
    if ($product) $state['products']++;
    return "+$award Kelopak" . ($product ? ' dan satu hak produk demo' : '') . " · hari ke-$streak";
}
