/// Barel mesin dan data Kelopak (tanpa UI): inti, domain, penyimpanan,
/// backend, controller, dan antarmuka host.
///
/// `lib/kelopak_hub.dart` mengekspor ulang berkas ini bersama zona Hadiah.
library;

export 'package:daily_checkin/daily_checkin.dart'
    show CheckInAward, CheckInRules;
export 'package:misi_belanja/misi_belanja.dart'
    show
        MissionDecision,
        MissionProgress,
        MissionStage,
        OrderRejection,
        RedeemProblem,
        StageStatus;
export 'package:roda_sabtu/roda_sabtu.dart'
    show
        PrizeKind,
        SpinConfig,
        SpinEligibility,
        SpinOdds,
        SpinPrize,
        WheelOpening,
        WheelSliceSpec;

export '../backend/kelopak_backend.dart';
export '../backend/local_kelopak_backend.dart';
export '../backend/remote_kelopak_backend.dart';
export '../backend/reply_codec.dart';
export '../controller/kelopak_controller.dart';
export '../controller/kelopak_event.dart';
export '../controller/kelopak_scope.dart';
export '../domain/campaign.dart';
export '../domain/checkout.dart';
export '../domain/engine.dart';
export '../domain/gifts.dart';
export '../domain/ledger.dart';
export '../domain/outcomes.dart';
export '../domain/state.dart';
export '../domain/voucher.dart';
export '../host/kelopak_host.dart';
export '../kit/game_cue.dart' show GameCue;
export '../storage/json_reader.dart';
export '../storage/kelopak_document.dart';
export '../storage/key_value_store.dart';
export '../storage/migrate_v2.dart';
export '../storage/revisioned_document.dart';
export 'format.dart';
export 'paths.dart';
export 'units.dart';
export 'wib_clock.dart';
