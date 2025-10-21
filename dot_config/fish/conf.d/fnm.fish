# fnm (Fast Node Manager) initialization
if test -d ~/.local/share/fnm
    set -gx PATH ~/.local/share/fnm $PATH
    fnm env | source
end
