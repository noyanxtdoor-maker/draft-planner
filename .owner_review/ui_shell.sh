#!/usr/bin/env bash
# Owner-review UI helper: dump | grep [text] | tap x y | back | key EVENT
# Usage: ./ui_shell.sh dump            -> pretty node list (text, desc, class, bounds)
#        ./ui_shell.sh grep "Tasks"    -> nodes containing text
#        ./ui_shell.sh tap 540 1200
D='adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp'
ADB='/c/Users/sherl/AppData/Local/Temp/next-transfer-toolchain/android-sdk/platform-tools/adb.exe'
case "$1" in
  dump)
    "$ADB" -s "$D" exec-out uiautomator dump /dev/tty 2>/dev/null \
      | grep -o '<node[^>]*>' \
      | sed -E 's/ [a-z-]*="(false|)"//g' \
      | grep -E 'text="[^"]+"|content-desc="[^"]+"' ;;
  grep)
    "$ADB" -s "$D" exec-out uiautomator dump /dev/tty 2>/dev/null \
      | grep -o '<node[^>]*>' | sed -E 's/ [a-z-]*="false//g' \
      | grep -i "$2" ;;
  tap)    "$ADB" -s "$D" shell input tap "$2" "$3" ;;
  swipe)  "$ADB" -s "$D" shell input swipe "$2" "$3" "$4" "$5" "${6:-300}" ;;
  back)   "$ADB" -s "$D" shell input keyevent KEYCODE_BACK ;;
  key)    "$ADB" -s "$D" shell input keyevent "$2" ;;
  text)   "$ADB" -s "$D" shell input text "$2" ;;
  screen) "$ADB" -s "$D" exec-out screencap -p > "$2" ;;
  *) echo "usage: dump|grep TEXT|tap X Y|swipe ...|back|key CODE|text STR|screen FILE" ;;
esac
