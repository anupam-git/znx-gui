#! /bin/sh

set -x

# -- Variables passed by the docker command.

TRAVIS_COMMIT=$1
TRAVIS_BRANCH=$2

# -- Install dependencies.

apt-get -qq -y update > /dev/null
apt-get -qq -y install wget patchelf file libcairo2 git > /dev/null
apt-get -qq -y install busybox-static kdialog kio libdbusmenu-qt5-2 libdouble-conversion1 libfam0 libkf5archive5 libkf5auth-data libkf5authcore5 libkf5codecs-data libkf5codecs5 libkf5completion-data libkf5completion5 libkf5config-data libkf5configcore5 libkf5configgui5 libkf5configwidgets-data libkf5configwidgets5 libkf5coreaddons-data libkf5coreaddons5 libkf5crash5 libkf5dbusaddons-data libkf5dbusaddons5 libkf5doctools5 libkf5guiaddons5 libkf5i18n-data libkf5i18n5 libkf5iconthemes-data libkf5iconthemes5 libkf5itemviews-data libkf5itemviews5 libkf5jobwidgets-data libkf5jobwidgets5 libkf5kiocore5 libkf5kiontlm5 libkf5kiowidgets5 libkf5notifications-data libkf5notifications5 libkf5service-bin libkf5service-data libkf5service5 libkf5solid5 libkf5solid5-data libkf5sonnet5-data libkf5sonnetcore5 libkf5sonnetui5 libkf5textwidgets-data libkf5textwidgets5 libkf5wallet-bin libkf5wallet-data libkf5wallet5 libkf5widgetsaddons-data libkf5widgetsaddons5 libkf5windowsystem-data libkf5windowsystem5 libkwalletbackend5-5 libpcre2-16-0 libpolkit-qt5-1-1 libqt5core5a libqt5dbus5 libqt5gui5 libqt5network5 libqt5qml5 libqt5script5 libqt5svg5 libqt5texttospeech5 libqt5widgets5 libqt5x11extras5 libqt5xml5 libxcb-xinerama0 libxcb-xinput0> /dev/null

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
