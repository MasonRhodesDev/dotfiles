{
  name = "Alex Example";
  emails = {
    personal = "alex@example.invalid";
    work = "alex@work.example.invalid";
  };
  git.includeIf = [
    { condition = "hasconfig:remote.*.url:git@github.com:example-personal/**"; identity = "personal"; }
    { condition = "hasconfig:remote.*.url:https://github.com/example-personal/**"; identity = "personal"; }
    { condition = "hasconfig:remote.*.url:git@github.com:example-org/**"; identity = "work"; }
    { condition = "hasconfig:remote.*.url:https://github.com/example-org/**"; identity = "work"; }
  ];
  tailnets.personal = "example-personal.example.invalid";
  buildHosts = {
    stub-headless = "stub-build-host-1:9936mxcSZHA/CAJNsKUhiegfLE38VnQr+TE6BMzk/ng=";
    stub-gaming-desktop = "stub-peer-build-host-1:9Q4NuJqXoenidGX8SaCl2mzrXoDF5y+ESWL+CsWpMAY=";
  };
  qbittorrent = { url = "http://qbittorrent.example.invalid:8080"; user = "alex"; };
  leakTerms = map (kind: "${kind}-placeholder") [ "leaked-name" "leaked-host" ];
  work = {
    claudeMd = "## Work\n\nExample employer guidance.";
    overlayUrl = "git@example.invalid:example-org/dotfiles-work.git";
  };
}
