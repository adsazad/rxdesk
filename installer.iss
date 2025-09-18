; installer.iss
[Setup]
AppName=SpiroBT
AppVersion=1.0.2
DefaultDirName={pf}\SpiroBT
DefaultGroupName=SpiroBT
OutputDir=build\installer
OutputBaseFilename=SpiroBT-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\SpiroBT"; Filename: "{app}\spirobtvo.exe"
Name: "{group}\Uninstall SpiroBT"; Filename: "{uninstallexe}"