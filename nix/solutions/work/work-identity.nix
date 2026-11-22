{
  name = "Work identity";
  description = "Work git email, work section of CLAUDE.md, and the private work overlay that feeds the pre-commit secret guard, and where Claude Code is, Claude's templates.";
  platforms = [ "linux" "darwin" ];

  home = { config, lib, pkgs, machine, identity, ... }:
    let
      work = identity.work or { };
      overlay = work.overlayUrl or null;
    in
    {
      programs.git.settings.user.email = lib.mkIf (identity.emails ? work) identity.emails.work;

      dotfiles.fragments."claude/CLAUDE.md/work" =
        lib.mkIf (lib.elem "claude-code" machine.enabled && work ? claudeMd) "${lib.removeSuffix "\n" work.claudeMd}\n";

      home.activation.workOverlay = lib.mkIf (overlay != null) (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [[ ! -v DRY_RUN ]]; then
          ssh=${pkgs.openssh}/bin/ssh
          [ -x /usr/bin/ssh ] && ssh=/usr/bin/ssh
          ssh="$ssh -o BatchMode=yes -o ConnectTimeout=10"
          git=${pkgs.git}/bin/git
          cache="${config.xdg.dataHome}/dotfiles-work"
          if [ -d "$cache/.git" ]; then
            $git -C "$cache" remote set-url origin ${lib.escapeShellArg overlay} || true
            GIT_SSH_COMMAND="$ssh" $git -C "$cache" pull --ff-only --quiet || warnEcho "work overlay: pull failed, using the existing clone"
          elif rm -rf "$cache"; then
            GIT_SSH_COMMAND="$ssh" $git clone --quiet ${lib.escapeShellArg overlay} "$cache" || warnEcho "work overlay: clone failed (no access?), skipped"
          else
            warnEcho "work overlay: could not clear $cache, skipped"
          fi
          ${lib.optionalString (lib.elem "claude-code" machine.enabled) ''
            dest="${config.home.homeDirectory}/.claude/templates"
            if [ -d "$cache/templates" ]; then
              mkdir -p "$dest" && cp -a "$cache/templates/." "$dest/" || warnEcho "work overlay: copying the templates into $dest failed"
              [ ! -d "$dest" ] || chmod -R go-rwx "$dest" || warnEcho "work overlay: could not make $dest private"
            fi
          ''}
        fi
      '');
    };
}
