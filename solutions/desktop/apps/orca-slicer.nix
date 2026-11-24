{
  name = "OrcaSlicer";
  description = "3D-print slicer, the Flathub build, installed system-wide.";
  platforms = [ "linux" ];
  when.hardware = "3d-printer";

  linux.root = {
    packages = {
      arch = [ "flatpak" ];
      fedora = [ "flatpak" ];
    };
    script = ''
      flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      if ! flatpak info --system com.orcaslicer.OrcaSlicer >/dev/null 2>&1; then
        flatpak install --system --noninteractive flathub com.orcaslicer.OrcaSlicer
      fi
    '';
  };
}
