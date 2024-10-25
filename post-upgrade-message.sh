#!/bin/bash

# Chemins des fichiers de logs
indicator_file="$HOME/.offline-upgrade"
log_file="/var/log/dnf.log"
rpm_log="/var/log/dnf.rpm.log"
success="$HOME/offline_upgrade.success.log"
failure="$HOME/offline_upgrade.failure.log"
scriptname="$(basename "$0")"
bigerror="$HOME/${scriptname}.error"
rm -f "$bigerror" 2>/dev/null
touch "$bigerror"
icon="/usr/share/swcatalog/icons/fedora/128x128/org.mageia.dnfdragora.png"
declare -i attempt=0
declare -i max_attempts=9

############################################################################################################################
format_date() {
    date_string="$1"
    formatted_date=$(date -d "$date_string" "+%d %B %Y à %Hh%M")
    echo "$formatted_date"
}
############################################################################################################################
check-new-conf-file() { 
    # Récupérer et convertir le timestamp de la mise à jour hors-ligne
    offline_timestamp=$(head -n 1 "$success" | awk '{print $1}')
    offline_epoch=$(date --date="$offline_timestamp" +%s)
    
    # Rechercher toutes les lignes dans dnf.rpm.log créant un fichier rpmnew, rpmsave, ou rpmorig
    grep -E "\.rpm(new|save|orig)" "$rpm_log" | while IFS= read -r line; do
        # Vérifier si la ligne contient un timestamp
        line_timestamp=$(echo "$line" | awk '{print $1" "$2}' | sed 's/[^0-9T:+-]//g')
        # Vérifier si le timestamp est vide ou invalide
        if [[ -z "$line_timestamp" || ! "$line_timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
			{ echo ; echo "Avertissement : Pas de timestamp valide trouvé pour la ligne suivante :" ; grep -A5 "$line" "$rpm_log" ; } >> "$bigerror"
           	continue
        fi
        # convertir le timestamp et géré les erreurs
        if ! line_epoch=$(date --date="$line_timestamp" +%s 2>/dev/null) ; then
		   { echo ; echo "Erreur de conversion du timestamp pour la ligne : " ; grep -A5 "$line" "$rpm_log" ; } >> "$bigerror" 
           continue
        fi
        # Calculer la différence de temps entre les timestamps
        time_diff=$((line_epoch - offline_epoch))
        time_diff=${time_diff#-} # Valeur absolue

        # Si la différence de temps est inférieure ou égale à 60 secondes, on considère le fichier comme pertinent
        if [ "$time_diff" -le 60 ]; then
            config_file=$(echo "$line" | grep -oP '(?<=created as |saved as |enregistré sous ).*\.(rpmnew|rpmsave|rpmorig)')
            echo -e "\n==> Nouveau fichier de configuration trouvé ($config_file) installé le $offline_timestamp." >> "$success"
        fi
    done
}
############################################################################################################################
if [ -f "$indicator_file" ]; then
    # Attendre que D-Bus soit prêt
    while ! dbus-send --session --dest=org.freedesktop.Notifications --type=method_call \
            /org/freedesktop/Notifications org.freedesktop.Notifications.GetCapabilities >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo "Avertissement : D-Bus n'est toujours pas prêt après $attempt tentatives. Continuation du script quand même." > "$bigerror"
            break  # Sortie de la boucle et continuation du script
        fi
        sleep 5
    done
    sleep 5
    last_result=$(tac "$log_file" | grep -m 1 -E 'Complete!|Terminé|err')
    update_time=$(echo "$last_result" | awk '{print $1}')
    readable_time=$(format_date "$update_time")
    last_result=${last_result,,} # on passe tout en minuscules
    if [[ $last_result == *"complete"* ]]; then
        grep "${update_time}" "$log_file" | awk 'NR==1 {print $1, $3, $4, $5, $6, $7, $8, $9} NR>1 {$1=$2=""; print $0}' > "$success"
        check-new-conf-file
        notify-send -i "$icon" --app-name "Mise à jour hors-ligne" "Effectuée correctement le $readable_time." "Fichier de log : $success"
    elif [[ $last_result == *"terminé"* ]]; then
        grep "${update_time}" "$log_file" | awk 'NR==1 {print $1, $3, $4, $5, $6, $7, $8, $9} NR>1 {$1=$2=""; print $0}' > "$success"
        check-new-conf-file
        notify-send -i "$icon" --app-name "Mise à jour hors-ligne" "Effectuée correctement le $readable_time." "Fichier de log : $success"
    elif [[ $last_result == *"err"* ]]; then
        grep "${update_time}" "$log_file"> "$failure"
        notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "En échec le $readable_time." "Fichier de log : $failure"
    else
        # Si aucune information claire n'est trouvée
        grep "${update_time}" "$log_file" > "$failure"
        notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "Résultat inconnu." "Fichier de log : $failure"
    fi
    rm -f "$indicator_file"
fi
