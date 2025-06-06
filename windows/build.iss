; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

#define MyAppName "Kostori"
#define MyAppVersion "{{version}}"
#define MyAppPublisher "AXLMLY"
#define MyAppURL "https://github.com/kostori-app/kostori"
#define MyAppExeName "kostori.exe"
#define RootPath "{{root_path}}"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{341E09FA-DCCC-429B-853B-AFC609ACDA7A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; Uncomment the following line to run in non administrative install mode (install for current user only.)
;PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#RootPath}\build\windows
OutputBaseFilename=Kostori-{#MyAppVersion}-windows-installer
SetupIconFile={#RootPath}\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "{#RootPath}\windows\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#RootPath}\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\dynamic_color_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\app_links_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\flutter_inappwebview_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\file_selector_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\app_links_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\sqlite3_flutter_libs_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\flutter_qjs_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\desktop_webview_window_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\share_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\battery_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\local_auth_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\zip_flutter.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\media_kit_video_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\media_kit_libs_windows_video_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\libEGL.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\libmpv-2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\libGLESv2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\flutter_volume_controller_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#RootPath}\build\windows\x64\runner\Release\rhttp.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\dynamic_color_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootPath}\build\windows\x64\runner\Release\volume_controller_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall