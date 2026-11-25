import 'package:flutter/services.dart';

/// Titik ribuan otomatis. Pakai koma untuk desimal (maks 2 digit).
class MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;
    var cur = newValue.selection.end;
    if (cur < 0 || cur > raw.length) cur = raw.length;

    var sig = 0;
    var comma = false;
    final b = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      final u = ch.codeUnitAt(0);
      final isDigit = u >= 48 && u <= 57;
      if (isDigit || (ch == ',' && !comma)) {
        if (ch == ',') comma = true;
        b.write(ch);
        if (i < cur) sig++;
      }
    }

    final s = b.toString();
    final ci = s.indexOf(',');
    var ip = ci >= 0 ? s.substring(0, ci) : s;
    String? fp = ci >= 0 ? s.substring(ci + 1) : null;
    if (fp != null && fp.length > 2) fp = fp.substring(0, 2);
    ip = ip.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (ip.isEmpty && fp != null) ip = '0';
    final g = ip.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    final out = fp == null ? g : '$g,$fp';

    var pos = 0, cnt = 0;
    while (pos < out.length && cnt < sig) {
      if (out[pos] != '.') cnt++;
      pos++;
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}
