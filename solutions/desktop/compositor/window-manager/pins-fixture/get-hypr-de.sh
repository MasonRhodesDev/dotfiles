KEY_URL="https://keys.example.invalid/repo.asc"
KEY_FPR="CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
REPO_URL="https://repo.example.invalid/x86_64"
cat >> /etc/pacman.conf <<SECTION
[fixture]
SECTION
COPR_KEYS=(
    "owner/one  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
)
