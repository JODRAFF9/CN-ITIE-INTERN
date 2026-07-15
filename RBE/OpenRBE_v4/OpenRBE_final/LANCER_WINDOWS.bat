@echo off
chcp 65001 > nul
title OpenRBE — ITIE Sénégal

echo.
echo  ╔══════════════════════════════════════════╗
echo  ║   OpenRBE — ITIE Sénégal                ║
echo  ║   Lancement automatique                  ║
echo  ╚══════════════════════════════════════════╝
echo.

:: Aller dans le dossier du script
cd /d "%~dp0"

:: Vérifier si Python est installé
python --version > nul 2>&1
if errorlevel 1 (
    python3 --version > nul 2>&1
    if errorlevel 1 (
        echo  ❌  Python n'est pas installé.
        echo.
        echo  Téléchargez Python sur : https://www.python.org/downloads/
        echo  Cochez bien "Add Python to PATH" lors de l'installation.
        echo.
        pause
        exit /b 1
    )
    set PYTHON=python3
) else (
    set PYTHON=python
)

:: Vérifier pandas et openpyxl
echo  🔍  Vérification des dépendances...
%PYTHON% -c "import pandas, openpyxl" > nul 2>&1
if errorlevel 1 (
    echo  📦  Installation des dépendances nécessaires...
    echo      (pandas et openpyxl — une seule fois)
    echo.
    %PYTHON% -m pip install pandas openpyxl --quiet
    if errorlevel 1 (
        echo  ❌  Échec de l'installation. Vérifiez votre connexion internet.
        pause
        exit /b 1
    )
    echo  ✅  Dépendances installées.
    echo.
)

:: Lancer build.py
echo  🔨  Génération de la plateforme depuis le fichier Excel...
echo.
%PYTHON% build.py
if errorlevel 1 (
    echo.
    echo  ❌  Erreur lors de la génération.
    pause
    exit /b 1
)

:: Ouvrir index.html dans le navigateur
echo  🌐  Ouverture dans le navigateur...
start "" "%~dp0index.html"

:: Fermer automatiquement après 3 secondes
echo.
echo  ✅  OpenRBE est prêt ! Cette fenêtre se ferme dans 3 secondes.
timeout /t 3 > nul
exit
