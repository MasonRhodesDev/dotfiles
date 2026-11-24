{
  name = "C toolchain";
  description = "gcc, make, cmake, pkg-config.";
  platforms = [ "linux" "darwin" ];

  linux.root = {
    packages = {
      arch = [ "gcc" "make" "cmake" "pkgconf" ];
      fedora = [ "gcc" "gcc-c++" "make" "cmake" "pkgconf-pkg-config" ];
    };
  };

  darwin.home = { pkgs, ... }: {
    home.packages = [ pkgs.cmake pkgs.pkg-config ];
  };
}
