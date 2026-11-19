# Guide de Packaging Windows Desktop (EXE & Inno Setup)

Ce document décrit la création de l'installeur Windows autonome pour ARIKE.

---

## 1. Compilation Release Windows

```powershell
cd frontend
flutter clean
flutter pub get
flutter build windows --release
```

Le dossier de sortie généré est :
`frontend/build/windows/x64/runner/Release/`

Contenu du dossier à packager :
- `ARIKE.exe` (exécutable principal)
- `flutter_windows.dll` (moteur Flutter)
- `sqlite3.dll` (moteur de base de données SQLite chiffré)
- Dossier `data/` (ressources graphiques, polices Google Fonts, assets)

---

## 2. Création de l'Installeur Exécutable (Inno Setup)

Dans le fichier `frontend/windows/packaging/arike_setup.iss` :
```iss
[Setup]
AppName=ARIKE POS
AppVersion=1.0.1
DefaultDirName={autopf}\ARIKE
DefaultGroupName=ARIKE
OutputDir=..\..\build\windows\installer
OutputBaseFilename=arike-setup-v1.0.1
Compression=lzma
SolidCompression=yes

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\ARIKE"; Filename: "{app}\ARIKE.exe"
Name: "{autodesktop}\ARIKE"; Filename: "{app}\ARIKE.exe"
```

Compilez le script avec l'outil Inno Setup Compiler (`iscc arike_setup.iss`).

