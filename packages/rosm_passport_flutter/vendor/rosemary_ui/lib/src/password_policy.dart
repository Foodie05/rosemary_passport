// Generated from design/input-validation.json; run pnpm design:generate.
class RosemaryPasswordResult {
  final bool length, characters, categories;
  const RosemaryPasswordResult({required this.length, required this.characters, required this.categories});
  bool get valid => length && characters && categories;
}
class RosemaryPasswordPolicy {
  static const minLength = 8;
  static const maxLength = 32;
  static const minimumCategories = 2;
  static const requirements = <String>["8–32 个字符","仅使用英文字母、数字和英文符号，不含空格","字母、数字、英文符号中至少包含两类"];
  static RosemaryPasswordResult check(String value) {
    final points = value.runes.toList();
    final letters = points.any((n) => n >= 65 && n <= 90 || n >= 97 && n <= 122);
    final digits = points.any((n) => n >= 48 && n <= 57);
    final symbols = points.any((n) => n >= 33 && n <= 126 && !(n >= 65 && n <= 90 || n >= 97 && n <= 122 || n >= 48 && n <= 57));
    return RosemaryPasswordResult(length: points.length >= minLength && points.length <= maxLength,
      characters: points.isNotEmpty && points.every((n) => n >= 33 && n <= 126),
      categories: [letters, digits, symbols].where((v) => v).length >= minimumCategories);
  }
}
