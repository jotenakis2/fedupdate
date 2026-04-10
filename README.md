# *fedupdate*
Script **bash** de mise à jour de __Fedora Linux__ basé sur dnf, flatpak et cargo.

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

**checkupdate.service** : permet de lancer fedupdate en mode vérification uniquement avec notification système (*fedupdate* -c -n -0 -I).

**checkupdate.timer** : permet de vérifier la présence de mise à jour toutes les 3 heures.

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

Le script utilise seulement des commandes dnf et, éventuellement, flatpak (PackageKit non-requis). Le script gère maintenant les paquets rust installés via cargo (crates.io).

Les erreurs de vérifications et de téléchargements sont gérées.

Le script doit être lancé par un utilisateur normal disposant du droit d'élévation de privilège (sudo).

## quelles sont les options de *fedupdate* ?
-   **-h, --help**

          Affiche l'aide,

-   **-C, --checkdeps**

          Pour vérifier les dépendances et afficher (ou recréer) le fichier de configuration,

-   **-s, --silent**

          Seule la liste de paquets sera affichée,

-   **-v, --verbose**

          Toutes les informations sont affichées,

-   **-c, --check**

          Le script vérifiera si des mises à jour sont disponibles mais ne les installera pas,

-   **-m, --notif_mail**

          Le script envoie un email si des mises à jour sont disponibles,

-   **-M, --nomail**

          Le script annule l'envoie d'un email (utile si option -m est activée par défaut dans config.rc),

-   **-n, --notify**

          Le script envoie une notification système si des mises à jour sont disponibles,

-   **-F, --noflatpak**

          La gestion des FLATPAKs est désactivée,

-   **-R, --norpm**

          La gestion des RPMs est désactivée,
         
-   **-A, --norust**

          La gestion des paquets rust installés via cargo est désactivée,

-   **-d, --direct**

          La mise à jour des RPMs sera directe, c'est-à-dire en ligne (non recommandé),

-   **-B, --nocacheupd**

          La mise à jour forcée du cache de dnf est ignorée,

-   **-d, --forcecacheupd**

          Le cache de dnf sera nettoyé et mis à jour,

-   **-p, --poweroff**

          L'ordinateur sera éteint après la mise à jour des RPMs,

-   **-P, --nopoweroff**

          L'ordinateur ne sera pas éteint,

-   **-0, --nolog**

          Les fichiers logs ne seront pas conservés,

-   **-D, --deletelog**

          Tous les logs de fedupdate seront supprimés,

-   **-4, --forcednf4**

          la commande dnf4 sera utilisée en lieu et place de la commande dnf,

-   **-5, --forcednf5**

          la commande dnf5 sera utilisée en lieu et place de la commande dnf,

-   **-L, --changelog**

          La liste des modifications apportées par les mises à jour sera affichée (RPM uniquement),

-   **-l, --limitlog**

          Seuls les logs en cas de mise à jour sont conservés,

-   **-u, --distrupgrade**

          Montée de version (de FC40 à FC41 par exemple),

-   **-i, --interactive**
          
          Le mode interactif est activé (questions posées systématiquement),
          
-   **-I, --nointeractive**
          
          Le mode interactif est désactivé (pas de question, mode normal).
          

## Notes importantes
-   Le mode "contrôle de fonctionnement" (-C) va permettre de générer le fichier de configuration et de vérifier les dépendances du script.

-   Le fichier de configuration conserve le mail nécessaire à l'option -m et le mot de passe de l'utilisateur.

-   Ce mot de passe, utilisé par la commande sudo, peut-être stocké en clair, ou chiffré si la bibliothèque openssl est installée.

-   Il conserve également des options à activer par défaut.

-   Le mode "notification par email" (-m) nécessite la commande mail et un MTA configuré (Mail Transport Agent, comme msmtp ou opensmtpd).

-   Une rotation des logs est effectuée à chaque exécution du script.

-   50 logs de chaque type sont conservés au maximum. Les logs vides sont automatiquement supprimés.

-   Le mode "verbeux" (-v) permet d'outrepasser le mode "pseudo-silencieux" (-s) si ce dernier est activé par défaut dans config.rc.

-   Le mode "pas de notification par email" (-M) permet d'outrepasser le mode "notification par email" (-m) si ce dernier est activé par défaut dans config.rc.

-   Le mode "pas d'extinction" (-P) permet d'outrepasser le mode "extinction" (-p) si ce dernier est activé par défaut dans config.rc.

-   Le mode "mise à jour forcée du cache" (-b) permet d'outrepasser le mode "pas de mise à jour du cache" (-B) si ce dernier est activé par défaut dans config.rc.


## Options par défaut

-   Les options suivantes peuvent être activées par défaut dans le fichier config.rc :

```
-4, --forcednf4
-5, --forcednf5
-L, --changelog
-s, --silent
-F, --noflatpak
-l, --limitlog
-p, --poweroff
-m, --notif_email
-B, --nocacheupd
-i, --interactive
```


## Dépendances
-	Paquet obligatoire pour installation automatique :
		make

-   Paquets obligatoires :
        bash, coreutils, dnf, findutils, gawk, libnotify, ncurses, sed, sudo et util-linux.

-   Paquets optionnels :
        s-nail, msmtp (ou opensmtpd), openssl et flatpak.
