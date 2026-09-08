import 'dart:io';
void main() {
  final s = File('android/app/src/main/res/drawable/ic_nt_notification.xml').readAsStringSync();
  final d = RegExp(r'pathData="([^"]+)"').firstMatch(s)!.group(1)!;
  final tok = RegExp(r'[A-Za-z]|[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
  var cur = ''; final nums = <double>[]; final xs = <double>[]; final ys = <double>[];
  for (final m in tok.allMatches(d)) {
    final t = m.group(0)!;
    if (t.length == 1 && RegExp(r'[A-Za-z]').hasMatch(t)) {
      for (var i = 0; i + 1 < nums.length; i += 2) { xs.add(nums[i]); ys.add(nums[i+1]); }
      nums.clear(); cur = t;
    } else { nums.add(double.parse(t)); }
  }
  for (var i = 0; i + 1 < nums.length; i += 2) { xs.add(nums[i]); ys.add(nums[i+1]); }
  xs.sort(); ys.sort();
  print('coords: ${xs.length} points');
  print('x: ${xs.first} .. ${xs.last}');
  print('y: ${ys.first} .. ${ys.last}');
  print('M count: ' + RegExp('M').allMatches(d).length.toString());
  print('Z count: ' + RegExp('Z').allMatches(d).length.toString());
  print('viewport 0..108 containment: ${xs.first >= 0 && xs.last <= 108 && ys.first >= 0 && ys.last <= 108}');
}
