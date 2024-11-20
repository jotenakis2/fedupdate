#!/bin/bash
set -euo pipefail
# variables globales
indicator_file="$HOME/.offline-upgrade"
success="$HOME/offline_upgrade.success.log"
failure="$HOME/offline_upgrade.failure.log"
rpm_log="/var/log/dnf.rpm.log"
scriptname="$(basename "$0")"
bigerror="$HOME/${scriptname}.error"
icon="/usr/share/swcatalog/icons/fedora/128x128/org.mageia.dnfdragora.png"
declare -i attempt=0
declare -i max_attempts=9


################################################################################################################################
#            SOUS-ROUTINES DU SCRIPT                                                                                           #
################################################################################################################################
CHECK_DNF_VERSION() {
    version_info=$($dnf --version 2>/dev/null)
    if echo "$version_info" | grep -q "4\."; then
        echo "dnf4"
    elif echo "$version_info" | grep -q "5\."; then
        echo "dnf5"
    else
        echo "Unable to determine DNF version." >> "$bigerror"
        exit 1
    fi
}
################################################################################################################################
FORMAT-DATE() {
    date_string="$1"
    formatted_date=$(date -d "$date_string" "+%d %B %Y à %Hh%M")
    echo "$formatted_date"
}
################################################################################################################################
CHECK-NEW-CONF-FILE() {
    # Récupérer et convertir le timestamp de la mise à jour hors-ligne
    offline_timestamp=$(head -n 1 "$success" | awk '{print $1}')
    offline_epoch=$(date --date="$offline_timestamp" +%s || echo 0)

    # Rechercher toutes les lignes dans dnf.rpm.log créant un fichier rpmnew, rpmsave, ou rpmorig
    grep -E "\.rpm(new|save|orig)" "$rpm_log" | while IFS= read -r line; do
        # Vérifier si la ligne contient un timestamp
        line_timestamp=$(echo "$line" | awk '{print $1" "$2}' | sed 's/[^0-9T:+-]//g')
        if [[ -z "$line_timestamp" || ! "$line_timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
            echo -e "\nAvertissement : Pas de timestamp valide trouvé pour la ligne suivante :" >> "$bigerror"
            grep -A5 "$line" "$rpm_log" >> "$bigerror"
            continue
        fi

        # Convertir le timestamp et gérer les erreurs
        line_epoch=$(date --date="$line_timestamp" +%s || {
            echo "Erreur de conversion du timestamp pour la ligne : " >> "$bigerror"
            grep -A5 "$line" "$rpm_log" >> "$bigerror"
            # shellcheck disable=SC2106
            continue
        })

        # Calculer la différence de temps entre les timestamps
        time_diff=$((line_epoch - offline_epoch))
        time_diff=${time_diff#-} # Valeur absolue

        # Si la différence de temps est inférieure ou égale à 60 secondes, on considère le fichier comme pertinent
        if [ "$time_diff" -le 120 ]; then
            config_file=$(echo "$line" | grep -oP '(?<=created as |saved as |enregistré sous ).*\.(rpmnew|rpmsave|rpmorig)')
            if [ -f "$config_file" ]; then
                echo -e "\n==> Nouveau fichier de configuration trouvé ($config_file) installé le $offline_timestamp." >> "$success"
            fi
        fi
    done
}
################################################################################################################################



################################################################################################################################
#                   CORPS DU SCRIPT                                                                                            #
################################################################################################################################
if [ -f "$indicator_file" ]; then
	rm -f "$bigerror"
	touch "$bigerror"
	# on récupère la version de dnf utilisée lors de la mise à jour hors-ligne
	dnf="$(cat "$indicator_file")"
	dnfver="$(CHECK_DNF_VERSION)"
	 # Attendre que D-Bus soit prêt
	while ! dbus-send --session --dest=org.freedesktop.Notifications --type=method_call \
	         /org/freedesktop/Notifications org.freedesktop.Notifications.GetCapabilities >/dev/null 2>&1; do
	    attempt=$((attempt + 1))
	    if [ $attempt -ge $max_attempts ]; then
			echo "Avertissement : D-Bus n'est toujours pas prêt après $attempt tentatives. Continuation du script quand même." >> "$bigerror"
			break
		fi
		sleep 6
	done
#-------------
	if [ "$dnfver" = "dnf4" ]; then # dnf version 4
		log_file="/var/log/dnf.log"
	    last_result=$(tac "$log_file" | grep -m 1 -E 'Complete!|Terminé|err' || echo "Résultat inconnu")
	    update_time=$(echo "$last_result" | awk '{print $1}')
	    readable_time=$(FORMAT-DATE "$update_time")
	    last_result=${last_result,,}
	    if [[ $last_result == *"complete"* || $last_result == *"terminé"* ]]; then
	        grep "${update_time}" "$log_file" | awk 'NR==1 {print $1, $3, $4, $5, $6, $7, $8, $9} NR>1 {$1=$2=""; print $0}' > "$success"
	        CHECK-NEW-CONF-FILE
	        notify-send -i "$icon" --app-name "Mise à jour hors-ligne" "Effectuée correctement le $readable_time." "Fichier de log : $success"
	    elif [[ $last_result == *"err"* ]]; then
	        grep "${update_time}" "$log_file" > "$failure"
	        notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "En échec le $readable_time." "Fichier de log : $failure"
	    else
	        grep "${update_time}" "$log_file" > "$failure"
	        notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "Résultat inconnu." "Fichier de log : $failure"
	    fi
	# fin dnf version 4
#-------------
	elif [ "$dnfver" = "dnf5" ]; then  # dnf version 5
		log_file="/var/log/dnf5.log"
		last_result=$(tac "$log_file" | grep -m 1 -E 'Transaction complete!|error' || echo "Résultat inconnu")
		update_time=$(echo "$last_result" | awk '{print $1}')
		readable_time=$(FORMAT-DATE "$update_time")
		last_result=${last_result,,}
		if [[ $last_result == *"complete"* ]]; then
			awk '/INFO Starting offline transaction/{block=""; flag=1} flag{block = block $0 "\n"} /INFO Transaction complete!/{flag=0} END{printf "%s", block}' "$log_file" > "$success"
			CHECK-NEW-CONF-FILE
			notify-send -i "$icon" --app-name "Mise à jour hors-ligne" "Effectuée correctement le $readable_time." "Fichier de log : $success"
		elif [[ $last_result == *"error"* ]]; then
			awk '/INFO Starting offline transaction/{block=""; flag=1} flag{block = block $0 "\n"} /INFO Transaction error/{flag=0} END{printf "%s", block}' "$log_file" > "$failure"
			notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "En échec le $readable_time." "Fichier de log : $failure"
		else
			cat "$log_file" > "$failure"
			notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "Résultat inconnu." "Fichier de log : $failure"
		fi
	fi
	# fin dnf version 5
#-------------
	rm -f "$indicator_file"
fi
