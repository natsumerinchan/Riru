#!/system/bin/sh
MODDIR=${0%/*}

check_zygisk() {
  if [ "$ZYGISK_ENABLE" = "1" ]; then
    sed -Ei 's/^description=(\[.*][[:space:]]*)?/description=[ ⛔ Riru is not loaded because of Zygisk. ] /g' "$MIRRORPROP"
    exit
  fi
}

display_fails() {
  sed -Ei 's/^description=(\[.*][[:space:]]*)?/description=[ ⛔ app_process fails to run. ] /g' "$MIRRORPROP"
  cd "$MODDIR" || exit 1
}

if [ "$KSU" == "true" ]; then
  # KernelSU internal directory
  MODULESDIR="/data/adb"
  MIRRORPROP="$MODDIR/module.prop"
  check_zygisk
  # KernelSU does not support custom sepolicy patches yet
  ./magiskpolicy --live --apply "$MODDIR/sepolicy.rule"
  display_fails
  # Export our own resetprop tool to rirud
  export PATH="$PATH:$MODDIR"
  # Rirud must be started before ro.dalvik.vm.native.bridge being reset
  unshare -m sh -c "/system/bin/app_process -Djava.class.path=rirud.apk /system/bin --nice-name=rirud riru.Daemon 25206 $MODULESDIR $(getprop ro.dalvik.vm.native.bridge)&"
  # post-fs-data phase, REMOVING THE -n FLAG MAY CAUSE DEADLOCK!
  # ./resetprop -n --file "$MODDIR/system.prop"
else
  TMPPROP="$(magisk --path)/riru.prop"
  MIRRORPROP="$(magisk --path)/.magisk/modules/riru-core/module.prop"
  sh -Cc "cat '$MODDIR/module.prop' > '$TMPPROP'"
  if [ $? -ne 0 ]; then
    exit
  fi
  check_zygisk
  mount --bind "$TMPPROP" "$MIRRORPROP"
  display_fails
  flock "module.prop"
  mount --bind "$TMPPROP" "$MODDIR/module.prop"
  unshare -m sh -c "/system/bin/app_process -Djava.class.path=rirud.apk /system/bin --nice-name=rirud riru.Daemon $(magisk -V) $(magisk --path) $(getprop ro.dalvik.vm.native.bridge)&"
  umount "$MODDIR/module.prop"
fi

