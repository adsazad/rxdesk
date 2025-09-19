; installer.iss
[Setup]
AppName=BlueVO2
AppVersion=1.0.2
DefaultDirName={pf}\BlueVO2
DefaultGroupName=BlueVO2
OutputDir=build\installer
OutputBaseFilename=BlueVO2-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\BlueVO2"; Filename: "{app}\bluevo2.exe"
Name: "{group}\Uninstall BlueVO2"; Filename: "{uninstallexe}"