/// 강아지 짖음/소리 상황 분류 (Yin & McCowan 2004, Pongrácz 등 2005 등 반려견
/// 발성 상황 연구와 국내외 "반려견 번역" 서비스의 분류 기준을 참고해 정리한
/// 12가지 상황 1차 버전).
enum DogSituation {
      greeting, // 인사/반가움
      wantsAttention, // 관심요구
      hungry, // 배고픔/밥요구
      playInvitation, // 놀이요청
      content, // 만족/편안함
      fearAnxiety, // 두려움/불안
      threatWarning, // 위협/경계
      pain, // 고통/아픔
      aggression, // 공격성/다툼
      alertStranger, // 낯선 사람(소리) 경계경보
      puppyWhine, // 애착/보채는 낑낑거림
      separationHowl, // 분리불안/야간 하울링
      unknown, // 분류 실패 (개 소리는 맞지만 특정 못함)
}

/// 상황별 분위기 그룹 (화면 색상 톤을 정할 때 사용).
enum SituationMood { happy, needy, caution, danger, playful, unknown }

class SituationInfo {
      final String koreanLabel;
      final String spokenPhrase; // TTS로 읽어줄 문장 (강아지가 직접 말하는 느낌의 귀여운 말투)
      final String emoji;
      final SituationMood mood;

      const SituationInfo(this.koreanLabel, this.spokenPhrase, this.emoji, this.mood);
}

const Map<DogSituation, SituationInfo> kSituationInfo = {
      DogSituation.greeting:
          SituationInfo("인사/반가움", "주인님 오셨다멍! 반가워요멍~", "🐶", SituationMood.happy),
      DogSituation.wantsAttention:
          SituationInfo("관심요구", "저 좀 봐주세요멍~", "🥺", SituationMood.needy),
      DogSituation.hungry:
          SituationInfo("배고픔/밥요구", "배고파요멍... 밥 주세요멍!", "🍖", SituationMood.needy),
      DogSituation.playInvitation: SituationInfo(
                "놀이요청", "같이 놀아요멍! 신난다멍~", "🎾", SituationMood.playful),
      DogSituation.content:
          SituationInfo("만족/편안함", "완전 편안하다멍~ 기분 좋아요멍", "😌", SituationMood.happy),
      DogSituation.fearAnxiety: SituationInfo(
                "두려움/불안", "무서워요멍... 살살 다가와 주세요멍", "😨", SituationMood.caution),
      DogSituation.threatWarning: SituationInfo(
                "위협/경계", "더 가까이 오지 마세요멍! 경고하는 거예요멍", "😠", SituationMood.danger),
      DogSituation.pain:
          SituationInfo("고통/아픔", "어딘가 아픈 것 같아요멍... 살펴봐 주세요멍", "🤕", SituationMood.danger),
      DogSituation.aggression: SituationInfo(
                "공격성/다툼", "저리 가세요멍! 더 이상은 못 참아요멍", "💢", SituationMood.danger),
      DogSituation.alertStranger: SituationInfo(
                "낯선 사람 경계", "누가 왔어요멍! 조심하세요멍", "🚨", SituationMood.caution),
      DogSituation.puppyWhine: SituationInfo(
                "애착/보채는 신호", "주인님 어디 있어요멍...?", "🐾", SituationMood.needy),
      DogSituation.separationHowl: SituationInfo(
                "분리불안/야간 하울링", "혼자 있으니까 외로워요멍... 같이 있어주세요멍", "🌙", SituationMood.caution),
      DogSituation.unknown: SituationInfo(
                "분류 불가", "무슨 소리인지 아직 잘 모르겠어요멍...", "❓", SituationMood.unknown),
};
