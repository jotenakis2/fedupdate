# *fedupdate*
Script **bash** de mise à jour de __Fedora Linux__ basé sur dnf et flatpak.

## comment installer *fedupdate* ?
```
git clone https://codeberg.org/jotenakis/fedupdate.git && cd fedupdate && chmod +x ./install.sh && ./install.sh
```
Cela va installer *fedupdate* et *post-upgrade-message.sh* dans **/usr/local/bin**. 

*fedupdate* est le script principal.

*post-upgrade-message.sh* est un script permettant de savoir si une mise à jour hors-ligne s'est bien déroulée.


Le script d'installation va aussi installer trois unités systemd utilisateur : 

**checkupdate.service** : permet de lancer fedupdate en mode vérification uniquement avec notification système (*fedupdate* -c -n).

**checkupdate.timer** : permet de vérifier la présence de mise à jour toutes les 2 heures.

**postupgrade.service** : permet de vérifier, au 1er reboot, si une mise à jour hors-ligne s'est bien passée.


## c'est quoi *fedupdate* ?
Ce script vérifie si les paquets **RPMs**, et éventuellement **FLATPAKs**, de votre *Fedora Linux* nécessitent une mise à jour.

Si des nouveaux paquets **FLATPAKs** sont disponibles, il procède à la mise à jour immédiatement.

Si des paquets **RPMs** sont disponibles, il les télécharge puis redémarre le système pour une mise à jour hors-ligne (plus sûre).

Le script utilise seulement des commandes dnf et, éventuellement, flatpak (PackageKit non-requis).

Les erreurs de vérifications et de téléchargements sont gérées.

Le script doit être lancé par un utilisateur normal disposant du droit d'élévation de privilège (sudo).

## quelles sont les options de *fedupdate* ?
-   -h   affiche cette aide et quitte,

-   -C   affiche et vérifie la présence des dépendances puis quitte (**mode "contrôle des dépendances"**),

-   -s   avec cette option, seules les erreurs et la liste de paquets seront affichées (**mode "pseudo-silencieux"**),

-   -c   avec cette option, le script ne fera que vérifier si des mises à jour sont disponibles (**mode "vérification"**),

-   -m   avec cette option, le script envoie un email si des mises à jour sont disponibles (**mode "notification par email"**),

-   -n   avec cette option, le script envoie une notification système si des mises à jour sont disponibles (**mode "notification système"**),

-   -F   avec cette option, la gestion des FLATPAKs est désactivée (**mode "sans gestion des FLATPAKs"**),

-   -R   avec cette option, la gestion des RPMs est désactivée (**mode "sans gestion des RPMs"**),

-   -d   avec cette option (**non recommandée**), la mise à jour des RPMs sera directe, c'est-à-dire en ligne (**mode "mise à jour directe**"),

-   -B   avec cette option (**non recommandée**), le script ne fera pas de mise à jour forcée du cache de dnf (**mode "pas de mise à jour du cache"**),

-   -0   avec cette option, tous les fichiers logs seront détruits à la fin de l'éxécution du script (**mode "sans conservation des logs"**).








