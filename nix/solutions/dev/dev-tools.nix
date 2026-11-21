{
  name = "Dev tools";
  description = "Media, network, debugging and archive tools for dev machines: ffmpeg, ImageMagick, nmap, netcat, 7-Zip, adb, and strace on Linux.";
  platforms = [ "linux" "darwin" ];
  when.uses = "dev";

  home = { pkgs, ... }: {
    home.packages = with pkgs; [ ffmpeg imagemagick nmap netcat p7zip android-tools ];
  };

  linux.home = { pkgs, ... }: {
    home.packages = [ pkgs.strace ];
  };

  inventory = {
    packages = {
      linux = [ "ffmpeg" "imagemagick" "nmap" "netcat" "p7zip" "android-tools" "strace" ];
      darwin = [ "ffmpeg" "imagemagick" "nmap" "netcat" "p7zip" "android-tools" ];
    };
  };
}
