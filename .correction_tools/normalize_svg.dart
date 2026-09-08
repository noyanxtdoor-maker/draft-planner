// Agent tool: normalize the approved SVG into a single self-contained path.
// 1) bake each path's translate into its coordinates
// 2) scale to a 108x108 viewport, recentered on the ink bounding box
// 3) emit ONE <path> d string (all subpaths concatenated) for VectorDrawable
import 'dart:io';

void main(List<String> args) {
  final src = File(args[0]).readAsStringSync();
  final pathRe = RegExp(
    r'<path[^>]*d="([^"]+)"[^>]*transform="translate\(([-0-9.]+),([-0-9.]+)\)"',
  );
  final matches = pathRe.allMatches(src).toList();
  if (matches.isEmpty) {
    stderr.writeln('no transformed paths found');
    exit(1);
  }
  stdout.writeln('paths found: ' + matches.length.toString());

  // ---- minimal SVG path tokenizer + transformer (supports the constructs
  // present in this file: M C L Z H V with absolute coords) ----
  final numRe = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  final outParts = <String>[];

  for (final m in matches) {
    final d = m.group(1)!;
    final tx = double.parse(m.group(2)!);
    final ty = double.parse(m.group(3)!);
    final buf = StringBuffer();
    var i = 0;
    String? tok() {
      while (i < d.length && d[i] == ' ') {
        i++;
      }
      if (i >= d.length) return null;
      final ch = d[i];
      if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
        i++;
        return ch;
      }
      final n = numRe.firstMatch(d.substring(i));
      if (n == null) return null;
      i += n.end;
      return n.group(0);
    }

    var cmd = '';
    final nums = <double>[];
    while (true) {
      final t = tok();
      if (t == null) break;
      if (t.length == 1 && RegExp(r'[A-Za-z]').hasMatch(t)) {
        _flush(buf, cmd, nums);
        cmd = t;
        nums.clear();
      } else {
        nums.add(double.parse(t));
      }
    }
    _flush(buf, cmd, nums);
    // no trailing flush needed: tok() returning a letter flushes the previous
    // command, and a d-string always ends with a letter command (Z).

    // Second pass: bake the translate into absolute coordinates now and
    // track the ink bounding box for later viewport scaling.
    final raw = buf.toString();
    final out = StringBuffer();
    var j = 0;
    final numRe2 = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
    final cmdRe = RegExp(r'[A-Za-z]');
    var pending = <double>[];
    var cur = '';
    void flushPair() {
      for (var k = 0; k + 1 < pending.length; k += 2) {
        final x = pending[k] + tx;
        final y = pending[k + 1] + ty;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
      // H/V single-operand commands handled by caller contract (none present).
      if (pending.isNotEmpty) {
        for (var k = 0; k < pending.length; k += 2) {
          final x = pending[k] + tx;
          final y = pending[k + 1] + ty;
          out.write(x.toStringAsFixed(2));
          out.write(' ');
          out.write(y.toStringAsFixed(2));
          if (k + 2 < pending.length) out.write(' ');
        }
      }
      pending.clear();
    }

    while (j < raw.length) {
      final ch = raw[j];
      if (cmdRe.hasMatch(ch)) {
        flushPair();
        cur = ch;
        out.write(ch);
        j++;
        continue;
      }
      if (ch == ' ' || ch == ',') {
        j++;
        continue;
      }
      final n = numRe2.firstMatch(raw.substring(j));
      if (n == null) {
        j++;
        continue;
      }
      pending.add(double.parse(n.group(0)!));
      j += n.end;
    }
    flushPair();
    outParts.add(out.toString());
  }

  if (minX.isInfinite) {
    stderr.writeln('no coordinates found');
    exit(1);
  }
  final inkW = maxX - minX;
  final inkH = maxY - minY;
  final viewport = 108.0;
  final scale = (viewport - 12) / (inkW > inkH ? inkW : inkH); // 6dp padding
  final offX = (viewport - inkW * scale) / 2 - minX * scale;
  final offY = (viewport - inkH * scale) / 2 - minY * scale;
  stdout.writeln('ink box: ($minX,$minY)-($maxX,$maxY) size ${inkW}x$inkH scale=$scale');

  final d = outParts.join(' ');
  // Scale the combined path: rewrite numeric stream; M/C/L/Z structure kept.
  final sb = StringBuffer();
  var k = 0;
  var curCmd = '';
  final argsBuf = <double>[];
  void emitCmd(String c, List<double> a) {
    sb.write(c);
    // absolute M/C/L take x,y pairs; Z takes none
    final pairs = (c == 'Z') ? <double>[] : a;
    for (var p = 0; p + 1 < pairs.length; p += 2) {
      final x = pairs[p] * scale + offX;
      final y = pairs[p + 1] * scale + offY;
      sb.write(x.toStringAsFixed(2));
      sb.write(' ');
      sb.write(y.toStringAsFixed(2));
      if (p + 2 < pairs.length) sb.write(' ');
    }
  }

  final numRe3 = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
  while (k < d.length) {
    final ch = d[k];
    if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
      if (curCmd.isNotEmpty) emitCmd(curCmd, argsBuf);
      curCmd = ch;
      argsBuf.clear();
      k++;
      continue;
    }
    if (ch == ' ' || ch == ',') {
      k++;
      continue;
    }
    final n = numRe3.firstMatch(d.substring(k));
    if (n == null) {
      k++;
      continue;
    }
    argsBuf.add(double.parse(n.group(0)!));
    k += n.end;
  }
  if (curCmd.isNotEmpty) emitCmd(curCmd, argsBuf);

  final xml = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!-- Derived from the owner-approved logo SVG')
    ..writeln('     06cfded9-7c0a-46c4-a9bf-ae4678fdaf1e.svg (hand + planner/notebook).')
    ..writeln('     Monochrome single-path fill; Android tints it for notification use. -->')
    ..writeln('<vector xmlns:android="http://schemas.android.com/apk/res/android"')
    ..writeln('    android:width="24dp"')
    ..writeln('    android:height="24dp"')
    ..writeln('    android:viewportWidth="108"')
    ..writeln('    android:viewportHeight="108">')
    ..writeln('  <path')
    ..writeln('      android:fillColor="#FFFFFFFF"')
    ..writeln('      android:pathData="' + sb.toString() + '" />')
    ..writeln('</vector>');
  File(args[1]).writeAsStringSync(xml.toString());
  stdout.writeln('written: ' + args[1] + ' (' + (xml.length.toString()) + ' chars of pathData)');
}

void _flush(StringBuffer buf, String cmd, List<double> nums) {
  if (cmd.isEmpty) return;
  buf.write(cmd);
  for (final n in nums) {
    buf.write(n.toString());
    buf.write(' ');
  }
}
