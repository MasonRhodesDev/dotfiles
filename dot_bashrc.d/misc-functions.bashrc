# Enable playwright nix environment in current directory
playwright-nix-enable() {
    echo 'use nix ~/nix-environments/playwright.nix' > .envrc
    direnv allow .
}
