{
  name = "HeadsetControl";
  description = "Headset battery and sidetone.";
  platforms = [ "linux" ];
  when.headless = false;

  linux.root.packages = {
    arch = [ "headsetcontrol" ];
    fedora = [ "headsetcontrol" ];
  };
}
