#! /bin/sh

set -x

# -- Variables passed by the docker command.

TRAVIS_COMMIT=$1
TRAVIS_BRANCH=$2

# -- Install dependencies.

apt-get -qq -y update
apt-get -qq -y install wget patchelf file libcairo2 git > /dev/null
apt-get -qq -y install busybox-static kde-baseapps-bin > /dev/null

wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
wget -q https://gitlab.com/nitrux/tools/raw/master/copier

chmod +x appimagetool
chmod +x copier
chmod +x appdir/znx-gui

# -- Write the commit that generated this build.

sed -i "s/@TRAVIS_COMMIT@/${TRAVIS_COMMIT:0:7}/" appdir/znx-gui


# -- Populate appdir.

mkdir -p appdir/bin


# -- Install busybox.

./copier busybox appdir
/bin/busybox --install -s appdir/bin


# -- Copy binaries and its dependencies to appdir.

./copier kdialog appdir


# -- Include znx.

ZNX_TMP_DIR=$(mktemp -d)
git clone https://github.com/Nitrux/znx $ZNX_TMP_DIR

(
	cd $ZNX_TMP_DIR

	bash build.sh

	rm \
		appdir/znx.desktop \
		appdir/znx.png \
		appdir/AppRun

)

cp -r $ZNX_TMP_DIR/appdir .


# -- Generate the AppImage.

(
	cd appdir

	wget -q https://raw.githubusercontent.com/AppImage/AppImages/master/functions.sh
	chmod +x functions.sh
	. ./functions.sh
	delete_blacklisted
	rm functions.sh

	wget -qO runtime https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-x86_64
	chmod a+x runtime

	find lib/x86_64-linux-gnu -type f -exec patchelf --set-rpath '$ORIGIN/././' {} \;
	find bin -type f -exec patchelf --set-rpath '$ORIGIN/../lib/x86_64-linux-gnu' {} \;
	find sbin -type f -exec patchelf --set-rpath '$ORIGIN/../lib/x86_64-linux-gnu' {} \;
	find usr/bin -type f -exec patchelf --set-rpath '$ORIGIN/../../lib/x86_64-linux-gnu' {} \;
	find usr/sbin -type f -exec patchelf --set-rpath '$ORIGIN/../../lib/x86_64-linux-gnu' {} \;
)

wget -q https://raw.githubusercontent.com/Nitrux/appimage-wrapper/master/appimage-wrapper
chmod a+x appimage-wrapper

UPDATE_URL="zsync|https://github.com/Nitrux/znx-gui/releases/download/continuous-development/znx-gui_$TRAVIS_BRANCH-x86_64.AppImage"

mkdir out
ARCH=x84_64 ./appimage-wrapper appimagetool -u "$UPDATE_URL" appdir out/znx-gui_$TRAVIS_BRANCH-x86_64.AppImage
