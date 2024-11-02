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
-   **-h,--help** :     affiche cette aide et quitte,

-   **-C,--checkdeps** :     affiche et/ou crée le fichier de configuration, puis contrôle les dépendances (**mode "contrôle du fonctionnement"**),

-   **-s,--silent** :     avec cette option, seules les erreurs et la liste de paquets seront affichées (**mode "pseudo-silencieux"**),

-   **-c,--check** :     avec cette option, le script ne fera que vérifier si des mises à jour sont disponibles (**mode "vérification"**),

-   **-m,--email** :     avec cette option, le script envoie un email si des mises à jour sont disponibles (**mode "notification par email"**),

-   **-n,--notify** :      avec cette option, le script envoie une notification système si des mises à jour sont disponibles (**mode "notification système"**),

-   **-F,--noflatpak** :     avec cette option, la gestion des FLATPAKs est désactivée (**mode "sans gestion des FLATPAKs"**),

-   **-R,--norpm** :     avec cette option, la gestion des RPMs est désactivée (**mode "sans gestion des RPMs"**),

-   **-d,--direct** :     avec cette option (**non recommandée**), la mise à jour des RPMs sera directe, c'est-à-dire en ligne (**mode "mise à jour directe**"),

-   **-B,--nocacheupd** :     avec cette option (**non recommandée**), le script ne fera pas de mise à jour forcée du cache de dnf (**mode "pas de mise à jour du cache"**),

-   **-p,--poweroff** :     avec cette option, l'ordinateur sera éteint après la mise à jour (mode "extinction"),

-   **-0,--nolog** :     avec cette option, tous les fichiers logs seront détruits à la fin de l'éxécution du script (**mode "sans conservation des logs"**).


## Notes importantes
-   Le mode "contrôle de fonctionnement" (-C) va permettre de générer le fichier de configuration et de vérifier les dépendances du script.

-   Le fichier de configuration conserve le mail nécessaire à l'option -m et le mot de passe de l'utilisateur.

-   Ce mot de passe, utilisé par la commande sudo, peut-être stocké en clair, ou chiffré si la bibliothèque openssl est installée.

-   Le mode "notification par email" (-m) et le mode "notification système" (-n) ne sont appliqués qu'en mode "vérification" (-c). Ils sont ignorés sinon.

-   Le mode "notification par email" (-m) n'est appliqué que si le script est lancé en arrière plan (via une tâche cron ou une unité systemd).

-   Le mode "notification par email" (-m) nécessite la commande mail et un MTA configuré (Mail Transport Agent, comme msmtp ou opensmtpd).

-   Le script utilise /usr/bin/dnf4 (dnf5 n'est pas supporté pour le moment).

## Dépendances
-	Paquet obligatoire pour installation automatique :
		make

-   Paquets obligatoires :
        bash, coreutils, dnf (v4), findutils, gawk, libnotify, ncurses, sed, sudo et util-linux.

-   Paquets optionnels :
        s-nail, msmtp (ou opensmtpd), openssl et flatpak.
