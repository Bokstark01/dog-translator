import 'package:flutter/material.dart';

import 'main.dart';

/// 인트로 애니메이션 다음에 보여주는 화면.
/// 사용자에게 강아지 이름을 입력받아 채팅방 전체에서 그 이름으로 부른다.
///
/// 색상/톤은 "피치 선셋" 디자인 시안을 따른다.
/// 메인 코랄(#FF9A76)·포인트 골드(#FFD36B)·크림 배경(#FFF6E9→#FFE3C9).
class DogNameScreen extends StatefulWidget {
  const DogNameScreen({super.key});

  @override
  State<DogNameScreen> createState() => _DogNameScreenState();
}

class _DogNameScreenState extends State<DogNameScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    final name = _controller.text.trim();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatHomePage(dogName: name.isEmpty ? '멍멍이' : name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF6E9), Color(0xFFFFE3C9)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFCDA8), Color(0xFFFFE1A0)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD36B).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Text('🐶', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 24),
                const Text(
                  '우리 강아지 이름이 뭔가요?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A3524),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '채팅방에서 이 이름으로 불러드릴게요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF9A8268).withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _controller,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    onSubmitted: (_) => _start(),
                    style: const TextStyle(
                      color: Color(0xFF4A3524),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '예: 초코',
                      hintStyle: TextStyle(
                        color: const Color(0xFF9A8268).withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color(0xFFFFD36B),
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _start,
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9A76), Color(0xFFFFD36B)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFFFD36B).withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '시작하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _start,
                  child: Text(
                    '나중에 정할게요',
                    style: TextStyle(
                      color: const Color(0xFF9A8268).withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
