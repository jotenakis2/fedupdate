#!/bin/bash
sudo cp -f fedupdate /usr/local/bin/
sudo cp -f post-upgrade-message.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/fedupdate 
sudo chmod 755 /usr/local/bin/post-upgrade-message.sh
sudo cp fedupdate.1 /usr/local/share/man/man1/
sudo mandb
# Unités Systemd user
mkdir -p "$HOME"/.config/systemd/user 2>/dev/null
cp -f checkupdate.* "$HOME"/.config/systemd/user/
cp -f postupgrade.service "$HOME"/.config/systemd/user/
systemctl --user daemon-reload  
# lance fedupdate -c -n pour faire un check seulement et notifier si une mise à jour est dispo
systemctl --user enable checkupdate.service  
# lance toutes les 2 heures checkupdate.service
systemctl --user --now enable checkupdate.timer 
# Vérifier au reboot si la mise à jour hors ligne s'est bien passée (notification système)
systemctl --user enable postupgrade.service
