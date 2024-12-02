# *CHANGELOG*

## version 1.95
-	mode -u, --distrupgrade pour monter en version (par exemple de Fedora 40 à 41).

- mode -l, --limitlog les logs ne sont conservés qu'en cas de mise à jour.

-	corrections de bugs, améliorations mineures cosmétiques.


## version 1.70
-	amélioration de la gestion des logs (plus de rotation des logs en mode "nolog").

-	amélioration du script post-upgrade-message.sh pour gérer les logs dnf5 multiples.


## version 1.65
- ajout dans le fichier de conf de la possibilité de faire un choix par défaut pour les options suivantes :

	--forcednf4

	--forcednf5

	--changelog

	--noflatpak

	--silent

	Relancer le script en mode -C pour refaire un fichier de configuration,

	puis éditer $HOME/.config/fedupdate/config.rc pour faire vos choix par défaut.

-	correction d'un bug du mode --changelog qui pouvait empécher la détection des paquets à mettre à jour.


## version 1.60
-	compatibilité dnf v5,
- mode --forcednf4 pour utiliser dnf4 (par défaut le script utilise /usr/bin/dnf),
- mode --forcednf5 pour utiliser dnf5 (par défaut le script utilise /usr/bin/dnf),
- mode --changelog, pour afficher la liste des modifs des paquets à mettre à jour,
- rotation des logs,
- nettoyage de code,
- bug fixes.

## version 1.50
-	Gestion des arguments longs de la ligne de commande,
- Robustification du code (compatible avec set -e),
- Nettoyage de code (les diverses utilisations de *dnf* et de *flatpak* sont maintenant dans des fonctions),
- Amélioration de l'affichage en mode normal et silencieux,
- Meilleure gestion des logs,
- Le script postupgrade détecte les rpmnew/rpmsave.


## todo pour version 2.0
-	mode *distroupgrade* pour monter en version (Fedora 40 à 41 par exemple).
