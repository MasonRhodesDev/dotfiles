playwright-nix-enable() {
    echo 'use nix ~/nix-environments/playwright.nix' > .envrc
    direnv allow .
}
