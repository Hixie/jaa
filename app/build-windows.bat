@ECHO OFF
call flutter clean
call flutter build windows
copy "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.44.35112\x64\Microsoft.VC143.CRT\msvcp140.dll" build\windows\x64\runner\Release
copy "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.44.35112\x64\Microsoft.VC143.CRT\vcruntime140.dll" build\windows\x64\runner\Release
copy "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.44.35112\x64\Microsoft.VC143.CRT\vcruntime140_1.dll" build\windows\x64\runner\Release
rename build\windows\x64\runner\Release jaa
cd build\windows\x64\runner
powershell Compress-Archive jaa jaa_windows.zip
cd ..\..\..\..
rename build\windows\x64\runner\jaa Release
echo build\windows\x64\runner\jaa_windows.zip
