import 'dart:math';
import 'cat_situation.dart';
import 'voice_discriminator.dart';

/// YAMNet(AudioSet) 라벨 중 개 소리와 관련된 하위 분류.
/// (Yin & McCowan 2004, Pongrácz 등 2005 등 반려견 발성 상황 연구와
/// 국내외 "반려견 번역" 서비스의 분류 기준을 참고한 1차 규칙)
enum DogSubLabel { bark, howl, growl, whimper, yip, generalDog, none }

class AudioFeatures {
  final double rms; // 음량 (0~1 근처로 정규화된 평균 에너지)
  final double pitchHz; // 추정 음높이 (영교차율 기반 근사치)
  final double durationMs; // 이번 발성이 이어진 길이
  final int repetitionCount; // 최근 몇 초 내 반복 횟수
  final int hourOfDay; // 0~23

  AudioFeatures({
    required this.rms,
    required this.pitchHz,
    required this.durationMs,
    required this.repetitionCount,
    required this.hourOfDay,
  });
}

/// YAMNet 점수 벡터 + 라벨 목록에서 "개 소리 관련 하위 라벨"과 신뢰도를 뽑아낸다.
/// 사람이 개 짖는 소리를 흉내 낸 경우를 걸러내기 위한 진단 정보도 함께
/// 담는다 (humanVoiceScore / formantDispersionHz).
class DogLabelResult {
  final DogSubLabel subLabel;
  final double confidence;
  final bool isDogSound;
  // --- 아래는 "사람이 흉내낸 소리" 판별용 진단 정보 (디버깅/피드백 로깅용) ---
  final double humanVoiceScore; // 같은 추론에서 나온 사람 목소리 계열 최고 점수.
  // bark/generalDog 계열이 애매할 때만 계산되는 참고용 진단 지표.
  // 견종별 성도 길이 편차가 너무 커서 이 값으로 소리를 거부하지는 않는다
  // (voice_discriminator.dart의 humanLikeFormantDispersionMaxHz 설명 참고).
  final double? formantDispersionHz;

  DogLabelResult(
    this.subLabel,
    this.confidence,
    this.isDogSound, {
    this.humanVoiceScore = 0,
    this.formantDispersionHz,
  });
}

/// 사람 목소리 점수가 개 소리 점수의 이 비율 이상이면 "사람이 낸 소리"로
/// 보고 거부한다. 1.0이면 사람 목소리 점수가 개 소리 점수를 넘어서야만
/// 거부하는 것이고, 1.0보다 작을수록(여기서는 0.9) 더 보수적으로(사람
/// 쪽에 더 유리하게) 판정한다 — 사람이 흉내 낸 "멍멍" 소리는 보통
/// Speech/Shout류 점수가 Bark 점수보다 훨씬 높게 나오기 때문에, 비슷한
/// 수준이기만 해도 의심하는 쪽이 오탐을 줄이는 데 유리하다.
const double _humanVoiceRejectionRatio = 0.9;

DogLabelResult pickDogSubLabel(
  List<double> scores,
  List<String> labels,
  List<double> waveform,
  int sampleRate,
) {
  // AudioSet(YAMNet) 라벨 중 개와 직접 관련된 항목들.
  const barkNames = {"bark", "bow-wow"};
  const howlNames = {"howl"};
  const growlNames = {"growling"};
  const whimperNames = {"whimper (dog)"};
  const yipNames = {"yip"};
  const generalDogNames = {"dog", "domestic animals, pets"};

  double bestScore = 0;
  DogSubLabel bestLabel = DogSubLabel.none;
  double humanVoiceScore = 0;

  for (int i = 0; i < scores.length && i < labels.length; i++) {
    final name = labels[i].toLowerCase().trim();
    final score = scores[i];
    DogSubLabel? candidate;
    if (barkNames.contains(name)) {
      candidate = DogSubLabel.bark;
    } else if (howlNames.contains(name)) {
      candidate = DogSubLabel.howl;
    } else if (growlNames.contains(name)) {
      candidate = DogSubLabel.growl;
    } else if (whimperNames.contains(name)) {
      candidate = DogSubLabel.whimper;
    } else if (yipNames.contains(name)) {
      candidate = DogSubLabel.yip;
    } else if (generalDogNames.contains(name)) {
      candidate = DogSubLabel.generalDog;
    } else if (humanVoiceLabelNames.contains(name)) {
      if (score > humanVoiceScore) humanVoiceScore = score;
    }
    if (candidate != null && score > bestScore) {
      bestScore = score;
      bestLabel = candidate;
    }
  }

  const threshold = 0.15;
  bool isDog = bestScore >= threshold && bestLabel != DogSubLabel.none;

  if (isDog && humanVoiceScore >= bestScore * _humanVoiceRejectionRatio) {
    isDog = false;
  }

  double? dispersion;

  if (isDog &&
      (bestLabel == DogSubLabel.bark || bestLabel == DogSubLabel.generalDog) &&
      humanVoiceScore >= bestScore * 0.5 &&
      humanVoiceScore < bestScore * _humanVoiceRejectionRatio) {
    final formants = estimateFormants(waveform, sampleRate);
    dispersion = formantDispersionHz(formants);
  }

  return DogLabelResult(
    bestLabel,
    bestScore,
    isDog,
    humanVoiceScore: humanVoiceScore,
    formantDispersionHz: dispersion,
  );
}

/// 개 소리임이 확인된 뒤, 하위 라벨 + 음향 특징으로
/// 12가지 상황 중 하나로 매핑한다. (규칙 기반 1차 버전)
///
/// 참고: 이 규칙은 Yin & McCowan, Pongrácz 등의 반려견 발성 상황 연구와
/// 선행 "강아지 번역" 서비스의 분류 기준을 바탕으로 만든 1차 근사치이며,
/// 추후 자체 데이터로 학습한 모델로 교체/보완할 예정입니다 (로드맵 2단계).
DogSituation mapToSituation(DogSubLabel subLabel, AudioFeatures f) {
  switch (subLabel) {
    case DogSubLabel.growl:
      return f.repetitionCount >= 2
          ? DogSituation.aggression
          : DogSituation.threatWarning;

    case DogSubLabel.howl:
      final isNight = f.hourOfDay >= 22 || f.hourOfDay < 6;
      return (isNight && f.repetitionCount >= 2)
          ? DogSituation.separationHowl
          : DogSituation.alertStranger;

    case DogSubLabel.whimper:
      if (f.durationMs > 6000 && f.rms < 0.2) {
        return DogSituation.pain;
      }
      if (f.pitchHz > 900 && f.repetitionCount >= 2 && f.durationMs <= 2000) {
        return DogSituation.puppyWhine;
      }
      return DogSituation.fearAnxiety;

    case DogSubLabel.yip:
      return (f.repetitionCount >= 3)
          ? DogSituation.playInvitation
          : DogSituation.wantsAttention;

    case DogSubLabel.bark:
    case DogSubLabel.generalDog:
      return _mapBark(f);

    case DogSubLabel.none:
      return DogSituation.unknown;
  }
}

DogSituation _mapBark(AudioFeatures f) {
  final isNight = f.hourOfDay >= 22 || f.hourOfDay < 6;
  final streakSeconds = (f.durationMs / 1000).round();

  if (f.repetitionCount >= 5 && streakSeconds >= 2) {
    return DogSituation.alertStranger;
  }

  if (isNight && f.repetitionCount >= 3) {
    return DogSituation.separationHowl;
  }

  if (f.repetitionCount >= 4 && streakSeconds <= 1 && f.rms > 0.3) {
    return DogSituation.playInvitation;
  }

  if (f.repetitionCount >= 2 && f.rms > 0.3) {
    return DogSituation.hungry;
  }

  if (f.repetitionCount <= 1 && streakSeconds <= 1) {
    return DogSituation.greeting;
  }

  if (f.repetitionCount <= 2 && f.rms.between(0.15, 0.3)) {
    return DogSituation.content;
  }

  return DogSituation.wantsAttention;
}

extension on double {
  bool between(double lo, double hi) => this >= lo && this <= hi;
}

/// "아니에요" 피드백을 받았을 때, 실제 상태일 확률이 높은 대안을 보여주기
/// 위한 1차 근사 점수. 진짜 통계적 확률은 아니고, 음향 특징이 각 상황의
/// 판정 규칙에 얼마나 가까운지를 0~1 사이 점수로 매긴 것이다.
/// (로드맵 2단계: 이 피드백을 모아 실제 확률 모델로 교체 예정)
List<DogSituation> topAlternativeSituations(
  DogSubLabel subLabel,
  AudioFeatures f,
  DogSituation excluding,
) {
  final scored = _scoreCandidates(subLabel, f);
  scored.removeWhere((entry) => entry.key == excluding);
  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.take(3).map((e) => e.key).toList();
}

double _clamp01(double v) => v.clamp(0.0, 1.0);

List<MapEntry<DogSituation, double>> _scoreCandidates(
    DogSubLabel subLabel, AudioFeatures f) {
  switch (subLabel) {
    case DogSubLabel.growl:
      return [
        MapEntry(DogSituation.aggression, f.repetitionCount >= 2 ? 1.0 : 0.4),
        MapEntry(
            DogSituation.threatWarning, f.repetitionCount < 2 ? 1.0 : 0.4),
        const MapEntry(DogSituation.fearAnxiety, 0.3),
      ];

    case DogSubLabel.howl:
      final isNight = f.hourOfDay >= 22 || f.hourOfDay < 6;
      final lonely = isNight && f.repetitionCount >= 2;
      return [
        MapEntry(DogSituation.separationHowl, lonely ? 1.0 : 0.4),
        MapEntry(DogSituation.alertStranger, lonely ? 0.4 : 1.0),
        const MapEntry(DogSituation.wantsAttention, 0.3),
      ];

    case DogSubLabel.whimper:
      return [
        MapEntry(DogSituation.fearAnxiety, 1.0),
        MapEntry(DogSituation.pain,
            (f.durationMs > 5000 && f.rms < 0.25) ? 0.8 : 0.3),
        const MapEntry(DogSituation.puppyWhine, 0.4),
      ];

    case DogSubLabel.yip:
      return [
        MapEntry(
            DogSituation.playInvitation, f.repetitionCount >= 3 ? 1.0 : 0.4),
        MapEntry(
            DogSituation.wantsAttention, f.repetitionCount < 3 ? 1.0 : 0.4),
        const MapEntry(DogSituation.greeting, 0.3),
      ];

    case DogSubLabel.bark:
    case DogSubLabel.generalDog:
      final isNight = f.hourOfDay >= 22 || f.hourOfDay < 6;
      final streakSeconds = (f.durationMs / 1000).round();
      return [
        MapEntry(
            DogSituation.alertStranger,
            _clamp01(f.repetitionCount / 5) * _clamp01(streakSeconds / 2)),
        MapEntry(DogSituation.separationHowl,
            (isNight ? 1.0 : 0.15) * _clamp01(f.repetitionCount / 3)),
        MapEntry(
            DogSituation.playInvitation,
            _clamp01(f.repetitionCount / 4) *
                (streakSeconds <= 1 ? 1.0 : 0.3) *
                _clamp01(f.rms / 0.3)),
        MapEntry(DogSituation.hungry,
            _clamp01(f.repetitionCount / 2) * _clamp01(f.rms / 0.3)),
        MapEntry(
            DogSituation.greeting,
            (f.repetitionCount <= 1 ? 1.0 : 0.3) *
                (streakSeconds <= 1 ? 1.0 : 0.3)),
        MapEntry(
            DogSituation.content,
            (f.repetitionCount <= 2 ? 1.0 : 0.3) *
                (f.rms.between(0.15, 0.3) ? 1.0 : 0.3)),
        const MapEntry(DogSituation.wantsAttention, 0.35),
      ];

    case DogSubLabel.none:
      return [const MapEntry(DogSituation.unknown, 1.0)];
  }
}

/// 매우 단순한 음향 특징 추출기 (영교차율 기반 피치 근사 + RMS).
/// 실시간 성능을 위해 FFT 대신 가벼운 연산만 사용한다.
class SimpleFeatureExtractor {
  final int sampleRate;
  SimpleFeatureExtractor(this.sampleRate);

  double rms(List<double> samples) {
    if (samples.isEmpty) return 0;
    double sumSq = 0;
    for (final s in samples) {
      sumSq += s * s;
    }
    return sqrt(sumSq / samples.length);
  }

  double approxPitchHz(List<double> samples) {
    if (samples.length < 2) return 0;
    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i - 1] < 0 && samples[i] >= 0) ||
          (samples[i - 1] >= 0 && samples[i] < 0)) {
        crossings++;
      }
    }
    final seconds = samples.length / sampleRate;
    final zcr = crossings / seconds;
    return zcr / 2;
  }
}
