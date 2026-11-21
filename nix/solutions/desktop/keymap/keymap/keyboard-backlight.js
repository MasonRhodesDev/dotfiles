function run(argv) {
  ObjC.import("Foundation");
  $.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/CoreBrightness.framework").load;
  const client = $.KeyboardBrightnessClient.alloc.init;
  const level = Math.min(1, Math.max(0, client.brightnessForKeyboard(1) + Number(argv[0])));
  client.setBrightnessFadeSpeedCommitForKeyboard(level, 250, true, 1);
}
