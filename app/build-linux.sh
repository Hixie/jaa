set -e
flutter clean
flutter build linux
pushd build/linux/x64/release
mv bundle jaa
zip --symlinks -r jaa_linux.zip jaa
mv jaa bundle
popd
echo build/linux/x64/release/jaa_linux.zip
