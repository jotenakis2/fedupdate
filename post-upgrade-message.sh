#!/bin/bash
indicator_file="$HOME/.offline-upgrade"
log_file="/var/log/dnf.log"
success="$HOME/offline_upgrade.success.log"
failure="$HOME/offline_upgrade.failure.log"
scriptname="$(basename "$0")"
bigerror="$HOME/.config/${scriptname}.error"
icon="/usr/share/swcatalog/icons/fedora/128x128/org.mageia.dnfdragora.png"
declare -i attempt=0
declare -i max_attempts=9

format_date() {
	date_string="$1"
	formatted_date=$(date -d "$date_string" "+%d %B %Y à %Hh%M")
	echo "$formatted_date"
}

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
		notify-send -i "$icon" --app-name "Mise à jour hors-ligne" "Effectuée correctement le $readable_time." "Fichier de log : $success"
	elif [[ $last_result == *"terminé"* ]]; then
                grep "${update_time}" "$log_file" | awk 'NR==1 {print $1, $3, $4, $5, $6, $7, $8, $9} NR>1 {$1=$2=""; print $0}' > "$success"
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
