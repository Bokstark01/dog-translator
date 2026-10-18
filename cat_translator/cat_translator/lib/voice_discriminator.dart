import 'dart:math';

/// 사람 목소리 계열 YAMNet(AudioSet) 라벨 이름 모음 (공식 클래스 인덱스
/// 0~35, AudioSet 온톨로지의 "Human voice" 상위 카테고리 전체).
/// 사람이 개 짖는 소리를 흉내낼 때도 결국 이 성대를 쓰기 때문에, 이 중
/// 하나라도 개 소리 라벨과 비슷하거나 더 높은 점수를 받으면 "사람이 낸
/// 소리일 가능성이 높다"는 신호로 쓴다.
const Set<String> humanVoiceLabelNames = {
    'speech',
    'child speech, kid speaking',
    'conversation',
    'narration, monologue',
    'babbling',
    'speech synthesizer',
    'shout',
    'bellow',
    'whoop',
    'yell',
    'children shouting',
    'screaming',
    'whispering',
    'laughter',
    'baby laughter',
    'giggle',
    'snicker',
    'belly laugh',
    'chuckle, chortle',
    'crying, sobbing',
    'baby cry, infant cry',
    'whimper',
    'wail, moan',
    'sigh',
    'singing',
    'child singing',
    'synthetic singing',
    'rapping',
    'humming',
    'groan',
    'grunt',
    'whistling',
};

/// scores/labels 중 사람 목소리 라벨의 최고 점수를 가져온다.
/// (개 소리 라벨 점수와 같은 YAMNet 추론 결과에서 공짜로 얻을 수 있어
/// 추가 연산 비용이 거의 없다.)
double maxHumanVoiceScore(List<double> scores, List<String> labels) {
    double best = 0;
    for (int i = 0; i < scores.length && i < labels.length; i++) {
          final name = labels[i].toLowerCase().trim();
          if (humanVoiceLabelNames.contains(name) && scores[i] > best) {
                  best = scores[i];
          }
    }
    return best;
}

// ---------------------------------------------------------------------
// 아주 가벼운 복소수 연산 (외부 패키지 없이 LPC 근 찾기에 사용).
// ---------------------------------------------------------------------
class Cplx {
    final double re;
    final double im;
    const Cplx(this.re, this.im);

    Cplx operator +(Cplx o) => Cplx(re + o.re, im + o.im);
    Cplx operator -(Cplx o) => Cplx(re - o.re, im - o.im);
    Cplx operator *(Cplx o) =>
            Cplx(re * o.re - im * o.im, re * o.im + im * o.re);
    Cplx operator /(Cplx o) {
          final d = o.re * o.re + o.im * o.im;
          if (d == 0) return const Cplx(0, 0);
          return Cplx((re * o.re + im * o.im) / d, (im * o.re - re * o.im) / d);
    }

    double get abs => sqrt(re * re + im * im);
    double get arg => atan2(im, re);
}

// ---------------------------------------------------------------------
// LPC(Linear Predictive Coding) 기반 포먼트 추출 — bark 흉내 판정 보조용.
// ---------------------------------------------------------------------

List<double> _autocorrelate(List<double> x, int maxLag) {
    final n = x.length;
    final r = List<double>.filled(maxLag + 1, 0.0);
    for (int lag = 0; lag <= maxLag; lag++) {
          double sum = 0;
          for (int i = 0; i < n - lag; i++) {
                  sum += x[i] * x[i + lag];
          }
          r[lag] = sum;
    }
    return r;
}

/// Levinson-Durbin 재귀로 LPC 계수를 구한다. 반환값은 a[0]=1.0을 포함해
/// 길이 order+1 (즉 [1, a1, a2, ..., aOrder]).
List<double> _levinsonDurbin(List<double> r, int order) {
    final a = List<double>.filled(order + 1, 0.0);
    a[0] = 1.0;
    if (r[0] == 0) return a;
    double e = r[0];
    for (int i = 1; i <= order; i++) {
          double acc = r[i];
          for (int j = 1; j < i; j++) {
                  acc += a[j] * r[i - j];
          }
          final k = -acc / e;
          final newA = List<double>.from(a);
          for (int j = 1; j < i; j++) {
                  newA[j] = a[j] + k * a[i - j];
          }
          newA[i] = k;
          for (int j = 0; j <= i; j++) {
                  a[j] = newA[j];
          }
          e *= (1 - k * k);
          if (e <= 1e-9) break;
    }
    return a;
}

/// Durand-Kerner(바이어슈트라스) 방법으로 다항식의 복소근을 구한다.
/// [coeffsHighToLow]는 최고차항부터 상수항까지 순서 (예: [1, a1, ..., aN]).
List<Cplx> _polynomialRoots(List<double> coeffsHighToLow) {
    final n = coeffsHighToLow.length - 1;
    if (n <= 0) return [];

    Cplx evalPoly(Cplx z) {
          Cplx result = const Cplx(0, 0);
          for (final c in coeffsHighToLow) {
                  result = result * z + Cplx(c, 0);
          }
          return result;
    }

    // 초기값은 단위원에 가깝게(반지름 0.9) 잡아야 수렴이 잘 된다.
    List<Cplx> roots = List.generate(n, (k) {
          final angle = 2 * pi * k / n + 0.5; // 대칭 배치로 인한 수렴 정체 방지용 오프셋.
          return Cplx(0.9 * cos(angle), 0.9 * sin(angle));
    });

    for (int iter = 0; iter < 50; iter++) {
          final newRoots = <Cplx>[];
          for (int i = 0; i < n; i++) {
                  Cplx denom = const Cplx(1, 0);
                  for (int j = 0; j < n; j++) {
                            if (j != i) denom = denom * (roots[i] - roots[j]);
                  }
                  if (denom.abs < 1e-12) {
                            newRoots.add(roots[i]);
                            continue;
                  }
                  newRoots.add(roots[i] - evalPoly(roots[i]) / denom);
          }
          roots = newRoots;
    }
    return roots;
}

/// waveform 중간 구간(32ms 프레임)에서 포먼트 주파수들(Hz, 오름차순)을
/// 가져온다. 소리가 너무 짧거나 무음에 가까우면 빈 리스트를 반환한다.
List<double> estimateFormants(List<double> waveform, int sampleRate) {
    const frameMs = 32;
    final frameLen = (sampleRate * frameMs / 1000).round();
    if (waveform.length < frameLen) return const [];

    final start = (waveform.length - frameLen) ~/ 2;
    final frame = waveform.sublist(start, start + frameLen);

    // 프리엠퍼시스: 고주파를 살짝 강조해 포먼트가 더 잘 드러나게 함.
    final pre = List<double>.filled(frame.length, 0.0);
    pre[0] = frame[0];
    for (int i = 1; i < frame.length; i++) {
          pre[i] = frame[i] - 0.97 * frame[i - 1];
    }

    final n = pre.length;
    for (int i = 0; i < n; i++) {
          pre[i] *= 0.54 - 0.46 * cos(2 * pi * i / (n - 1)); // Hamming window
    }

    final energy = pre.fold<double>(0, (s, v) => s + v * v);
    if (energy < 1e-6) return const []; // 거의 무음 -> 포먼트 추출 의미 없음.

    final order = (sampleRate / 1000).round() + 2; // 경험적 규칙 (16kHz -> 18차).
    final r = _autocorrelate(pre, order);
    final lpc = _levinsonDurbin(r, order); // [1, a1, ..., aOrder]

    final roots = _polynomialRoots(lpc);
    final freqs = <double>[];
    for (final root in roots) {
          if (root.im <= 0) continue; // 상반평면 근만 사용 (양의 주파수에 대응).
          final mag = root.abs;
          if (mag >= 0.995 || mag < 0.7) continue; // 단위원에 가깝고 지나치게 감쇠되지 않은 근만 포먼트로 인정.
          final freq = root.arg * sampleRate / (2 * pi);
          final bandwidth = -log(mag) * sampleRate / pi;
          if (freq > 90 && freq < sampleRate / 2 - 100 && bandwidth < 800) {
                  freqs.add(freq);
          }
    }
    freqs.sort();
    return freqs;
}

/// 포먼트 간격(중앙값, Hz) — 성도 길이에 반비례하는 지표
/// (ΔF ≈ 음속 / (2 × 성도길이), Fitch 등 동물음향학 연구에서 널리 쓰는 식).
/// 평균이 아니라 중앙값을 쓰는 이유: LPC 근 찾기 과정에서 가끔 끼어들어오는
/// 들어오는 가짜(허위) 포먼트 하나가 간격을 크게 왜곡할 수 있는데, 중앙값은
/// 이런 이상치 하나에 덜 민감하다 (합성 신호로 검증함).
double? formantDispersionHz(List<double> formants) {
    if (formants.length < 2) return null;
    final gaps = <double>[];
    for (int i = 1; i < formants.length; i++) {
          gaps.add(formants[i] - formants[i - 1]);
    }
    gaps.sort();
    final mid = gaps.length ~/ 2;
    if (gaps.length.isOdd) return gaps[mid];
    return (gaps[mid - 1] + gaps[mid]) / 2;
}

/// 사람 성인 평균 성도 길이(~17cm) 기준 추정 포먼트 간격(≈900~1200Hz)을
/// 참고용으로만 남겨둔 상수. 고양이와 달리 개는 치와와(체고 약 1~2kg)부터
/// 그레이트데인(체고 70kg이상)까지 취종간 체격/성도 길이 편차가 매우
/// 커서, 대형견은 사람 성인보다 성도가 길어 포먼트 간격이 오히려 사람보다
/// 좋거나 비슷할 수도 있다(Fitch 등 동물음향학 연구). 이 때문에 고양이처럼
/// 크기가 일관된 종과 달리, 개에게는 고정 임계값 하나로 "사람 성도에서 나는
/// 소리"를 판정할 과학적 근거가 부족하다. 그래서 pickDogSubLabel에서는 이
/// 값을 거부 판정에 쓰지 않고 참고/로깅용으로만 남겨둔다 (추후 견종 정보를 함께
/// 받을 수 있게 되면 개별 보정 지표로 활용 가능).
const double humanLikeFormantDispersionMaxHz = 1800.0;
