#!/bin/bash
# ══════════════════════════════════════════════════════
#  OpenRBE — ITIE Sénégal
#  Lanceur automatique macOS / Linux
#  Double-cliquez ou lancez : bash LANCER_MAC_LINUX.sh
# ══════════════════════════════════════════════════════

# Aller dans le dossier du script (même si lancé depuis ailleurs)
cd "$(dirname "$0")"

echo ""
echo " ╔══════════════════════════════════════════╗"
echo " ║   OpenRBE — ITIE Sénégal                ║"
echo " ║   Lancement automatique                  ║"
echo " ╚══════════════════════════════════════════╝"
echo ""

# ── Trouver Python ────────────────────────────────────
PYTHON=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        VER=$("$cmd" --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
        MAJOR=$(echo "$VER" | cut -d. -f1)
        if [ "$MAJOR" -ge 3 ]; then
            PYTHON="$cmd"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo " ❌  Python 3 n'est pas installé."
    echo ""
    echo " Pour l'installer :"
    echo "   macOS  : brew install python3"
    echo "            ou https://www.python.org/downloads/"
    echo "   Ubuntu : sudo apt install python3 python3-pip"
    echo ""
    read -p " Appuyez sur Entrée pour fermer..."
    exit 1
fi

echo " ✅  Python trouvé : $($PYTHON --version)"
echo ""

# ── Vérifier / installer dépendances ─────────────────
if ! $PYTHON -c "import pandas, openpyxl" &>/dev/null; then
    echo " 📦  Installation des dépendances (pandas, openpyxl)..."
    echo "     (première utilisation uniquement)"
    echo ""
    $PYTHON -m pip install pandas openpyxl --quiet
    if [ $? -ne 0 ]; then
        # Essayer avec pip3
        pip3 install pandas openpyxl --quiet 2>/dev/null
        if [ $? -ne 0 ]; then
            echo " ❌  Échec de l'installation. Essayez manuellement :"
            echo "     pip3 install pandas openpyxl"
            read -p " Appuyez sur Entrée pour fermer..."
            exit 1
        fi
    fi
    echo " ✅  Dépendances installées."
    echo ""
fi

# ── Lancer build.py ───────────────────────────────────
echo " 🔨  Génération de la plateforme depuis le fichier Excel..."
echo ""
$PYTHON build.py
BUILD_STATUS=$?

if [ $BUILD_STATUS -ne 0 ]; then
    echo ""
    echo " ❌  Erreur lors de la génération."
    read -p " Appuyez sur Entrée pour fermer..."
    exit 1
fi

# ── Ouvrir index.html dans le navigateur ─────────────
echo " 🌐  Ouverture dans le navigateur..."

# Détecter l'OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open "index.html"
elif command -v xdg-open &>/dev/null; then
    # Linux avec bureau
    xdg-open "index.html"
elif command -v gnome-open &>/dev/null; then
    gnome-open "index.html"
else
    echo " ℹ️  Ouvrez manuellement le fichier : $(pwd)/index.html"
fi

echo ""
echo " ✅  OpenRBE est prêt !"
echo ""
sleep 2
