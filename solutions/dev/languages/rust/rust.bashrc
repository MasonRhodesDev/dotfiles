case ":$PATH:" in
    *":$HOME/.cargo/bin:"*) ;;
    *) path_append "$HOME/.cargo/bin" ;;
esac
