#!/bin/bash

# Variables
BIN_DIR="/usr/local/bin"
MAN_DIR="/usr/local/share/man/man1"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SCRIPT1="fedupdate"
SCRIPT2="post-upgrade-message.sh"
MAN_PAGE="fedupdate.1"
SYSTEMD_UNITS=("checkupdate.service" "checkupdate.timer" "postupgrade.service")

# Fonction pour copier un fichier avec sudo et vérifier si la copie s'est bien passée
COPY_FILE() {
    local src=$1
    local dest=$2
    if sudo cp -f "$src" "$dest" 2>/dev/null; then
        echo "$src copié dans $dest"
    else
        echo "Erreur lors de la copie de $src vers $dest" >&2
        exit 1
    fi
}

# Fonction pour changer les permissions et vérifier
SET_PERMISSIONS() {
    local file=$1
    local permissions=$2
    if sudo chmod "$permissions" "$file"; then
        echo "Permissions $permissions définies pour $file"
    else
        echo "Erreur lors de la définition des permissions pour $file" >&2
        exit 1
    fi
}

# Copier les scripts dans /usr/local/bin et définir les permissions
COPY_FILE "$SCRIPT1" "$BIN_DIR"
COPY_FILE "$SCRIPT2" "$BIN_DIR"
SET_PERMISSIONS "$BIN_DIR/$SCRIPT1" 755
SET_PERMISSIONS "$BIN_DIR/$SCRIPT2" 755

# Copier la page de man
COPY_FILE "$MAN_PAGE" "$MAN_DIR"
sudo mandb >/dev/null 2>&1

# Unités Systemd utilisateur
mkdir -p "$SYSTEMD_USER_DIR" 2>/dev/null

for unit in "${SYSTEMD_UNITS[@]}"; do
    cp -f "$unit" "$SYSTEMD_USER_DIR/" 2>/dev/null
done

# Recharger les unités systemd et activer les services
systemctl --user daemon-reload
systemctl --user enable checkupdate.service
systemctl --user --now enable checkupdate.timer
systemctl --user enable postupgrade.service

echo "Installation et configuration terminées."
