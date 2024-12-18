set -eu

SOFTWARE_INSTALLER_LOCATION=$HOME/.software_installers

mkdir -p $SOFTWARE_INSTALLER_LOCATION

cd $SOFTWARE_INSTALLER_LOCATION

# check if ags is installedu
if ! command -v ags &> /dev/null; then
    sudo dnf install -y meson vala valadoc gtk3-devel gtk-layer-shell-devel gobject-introspection-devel

    if [ ! -d /tmp/astal ]; then
        git clone https://github.com/aylur/astal.git /tmp/astal
    fi
    cd /tmp/astal/lib/astal/io
    git pull
    meson setup --prefix /usr build
    sudo meson install -C build

    cd /tmp/astal/lib/astal/gtk3
    meson setup --prefix /usr build
    sudo meson install -C build

    cd $SOFTWARE_INSTALLER_LOCATION
    if [ ! -d astal ]; then
        git clone https://github.com/aylur/astal
    fi
    cd astal/lang/gjs
    git pull
    meson setup --prefix /usr build
    sudo meson install -C build

    cd $SOFTWARE_INSTALLER_LOCATION

    if [ ! -d ags ]; then
        git clone https://github.com/aylur/ags.git
    fi
    cd ags
    git pull
    go install -ldflags "\
        -X 'main.gtk4LayerShell=$(pkg-config --variable=libdir gtk4-layer-shell)/libgtk4-layer-shell.so' \
        -X 'main.astalGjs=$(pkg-config --variable=srcdir astal-gjs)'"
fi

cd $SOFTWARE_INSTALLER_LOCATION


