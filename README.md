# *fedupdate*
Script **bash** de mise à jour de __Fedora Linux__ basé sur dnf et flatpak.

## comment installer *fedupdate* ?
Installer fedupdate nécessite que le paquet **make** soit installé.
```
sudo dnf install make
```

```
git clone https://codeberg.org/jotenakis/fedupdate.git && cd fedupdate && make install
```
Cela va installer *fedupdate* et *post-upgrade-message.sh* dans **/usr/local/bin**.

*fedupdate* est le script principal.

*post-upgrade-message.sh* est un script permettant de savoir si une mise à jour hors-ligne s'est bien déroulée.


Le script d'installation va aussi installer trois unités systemd utilisateur :

**checkupdate.service** : permet de lancer fedupdate en mode vérification uniquement avec notification système (*fedupdate* -c -n).

**checkupdate.timer** : permet de vérifier la présence de mise à jour toutes les 2 heures.

**postupgrade.service** : permet de vérifier, au 1er reboot, si une mise à jour hors-ligne s'est bien passée.


Enfin, le script d'installation va installer une page de **man**.

## comment desinstaller *fedupdate* ?
Désinstaller fedupdate nécessite que le paquet **make** soit installé.
```
sudo dnf install make
```

```
git clone https://codeberg.org/jotenakis/fedupdate.git && cd fedupdate && make uninstall
```

Tous les paquets installés par fedupdate seront supprimés sauf les données utilisateurs (qui peuvent être supprimés manuellement):

```
rm -rf $HOME/.config/fedupdate/ $HOME/.local/share/fedupdate/ 2>/dev/null
```

## c'est quoi *fedupdate* ?
Ce script vérifie si les paquets **RPMs**, et éventuellement **FLATPAKs**, de votre *Fedora Linux* nécessitent une mise à jour.

Si des nouveaux paquets **FLATPAKs** sont disponibles, il procède à la mise à jour immédiatement.

Si des paquets **RPMs** sont disponibles, il les télécharge puis redémarre le système pour une mise à jour hors-ligne (plus sûre).

Le script utilise seulement des commandes dnf et, éventuellement, flatpak (PackageKit non-requis).

Les erreurs de vérifications et de téléchargements sont gérées.

Le script doit être lancé par un utilisateur normal disposant du droit d'élévation de privilège (sudo).

## quelles sont les options de *fedupdate* ?
-   **-h, --help**

          Affiche l'aide,

-   **-C, --checkdeps**

          Pour vérifier les dépendances et afficher (ou recréer) le fichier de configuration,

-   **-s, --silent**

          Seule la liste de paquets sera affichée,

-   **-c, --check**

          Le script vérifiera si des mises à jour sont disponibles mais ne les installera pas,

-   **-m, --email**

          Le script envoie un email si des mises à jour sont disponibles,

-   **-n, --notify**

          Le script envoie une notification système si des mises à jour sont disponibles,

-   **-F, --noflatpak**

          La gestion des FLATPAKs est désactivée,

-   **-R, --norpm**

          La gestion des RPMs est désactivée,

-   **-d, --direct**

          La mise à jour des RPMs sera directe, c'est-à-dire en ligne (**non recommandé**"),

-   **-B, --nocacheupd**

          La mise à jour forcée du cache de dnf est ignorée (**non recommandé**),

-   **-p, --poweroff**

          L'ordinateur sera éteint après la mise à jour des RPMs,

-   **-0, --nolog**

          Les fichiers logs ne seront pas conservés.

-   **-4, --forcednf4**

          la commande dnf4 sera utilisée en lieu et place de la commande dnf.

-   **-5, --forcednf5**

          la commande dnf5 sera utilisée en lieu et place de la commande dnf.

-   **-L, --changelog**

          La liste des modifications apportées par les mises à jour sera affichée.

-   **-l, --limitlog**

          Seuls les logs en cas de mise à jour sont conservés.

-   **-u, --distrupgrade**

          Montée de version (de FC40 à FC41 par exemple).


## Notes importantes
-   Le mode "contrôle de fonctionnement" (-C) va permettre de générer le fichier de configuration et de vérifier les dépendances du script.

-   Le fichier de configuration conserve le mail nécessaire à l'option -m et le mot de passe de l'utilisateur.

-   Ce mot de passe, utilisé par la commande sudo, peut-être stocké en clair, ou chiffré si la bibliothèque openssl est installée.

-   Le mode "notification par email" (-m) et le mode "notification système" (-n) ne sont appliqués qu'en mode "vérification" (-c). Ils sont ignorés sinon.

-   Le mode "notification par email" (-m) n'est appliqué que si le script est lancé en arrière plan (via une tâche cron ou une unité systemd).

-   Le mode "notification par email" (-m) nécessite la commande mail et un MTA configuré (Mail Transport Agent, comme msmtp ou opensmtpd).

-   Une rotation des logs est effectuée à chaque exécution du script.

-   9 logs RPMs et 9 logs FLATPAKs sont conservés au maximum. Les logs vides sont automatiquement supprimés.


## Dépendances
-	Paquet obligatoire pour installation automatique :
		make

-   Paquets obligatoires :
        bash, coreutils, dnf, findutils, gawk, libnotify, ncurses, sed, sudo et util-linux.

-   Paquets optionnels :
        s-nail, msmtp (ou opensmtpd), openssl et flatpak.
