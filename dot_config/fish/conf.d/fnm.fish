# fnm (Fast Node Manager) initialization
if test -d ~/.local/share/fnm
    set -gx PATH ~/.local/share/fnm $PATH
    if not command -q fnm; and test -x ~/.cargo/bin/fnm
        set -gx PATH ~/.cargo/bin $PATH
    end
    fnm env | source
end
