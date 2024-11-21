# *CHANGELOG*

## version 1.50
-	Gestion des arguments longs de la ligne de commande,
- Robustification du code (compatible avec set -e),
- Nettoyage de code (les diverses utilisations de *dnf* et de *flatpak* sont maintenant dans des fonctions),
- Amélioration de l'affichage en mode normal et silencieux,
- Meilleure gestion des logs,
- Le script postupgrade détecte les rpmnew/rpmsave.

## version 1.60
-	compatibilité dnf v5,
- mode --forcednf4 pour utiliser dnf4 (par défaut le script utilise /usr/bin/dnf),
- mode --forcednf5 pour utiliser dnf5 (par défaut le script utilise /usr/bin/dnf),
- mode --changelog, pour afficher la liste des modifs des paquets à mettre à jour,
- rotation des logs,
- nettoyage de code,
- bug fixes.

## todo pour version 2.0
-	mode *distroupgrade* pour montée en version (Fedora 40 à 41 par exemple),
