set -e
flutter clean
flutter build macos
pushd build/macos/Build/Products/Release/
zip --symlinks -r jaa_macos.zip 'FIRST Tech Challenge Judge Advisor Assistant.app'
popd
echo build/macos/Build/Products/Release/jaa_macos.zip
