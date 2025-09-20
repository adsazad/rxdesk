; installer.iss
[Setup]
AppName=HolterSync
AppVersion=1.0.2
DefaultDirName={pf}\HolterSync
DefaultGroupName=HolterSync
OutputDir=build\installer
OutputBaseFilename=HolterSync-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\HolterSync"; Filename: "{app}\holtersync.exe"
Name: "{group}\Uninstall HolterSync"; Filename: "{uninstallexe}"