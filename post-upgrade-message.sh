#!/bin/bash
indicator_file="$HOME/.offline-upgrade"
log_file="/var/log/dnf.log"
rpm_log="/var/log/dnf.rpm.log"
success="$HOME/offline_upgrade.success.log"
failure="$HOME/offline_upgrade.failure.log"
scriptname="$(basename "$0")"
bigerror="$HOME/.config/${scriptname}.error"
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
# fonction qui cherche dans le log de rpm si des paquets qui viennent de se mettre à jour ont crée un rpmnew, un rpmsave ou un rpmorig.
# si oui un message est ajouté à $HOME/offline_upgrade.success.log
# le principe est de comparer les paquets de $HOME/offline_upgrade.success.log (qui viennent du log de dnf) avec les paquets du log de rpm.
# si la date correspond, la fonction cherche dans le log de rpm la présence d'un nouveau rpmnew, rpmsave, rpmorig sous la ligne qui mentionne le paquet concerné.
# Exemple
# 	grep -A 1 "cups-browsed-1:2.0.1-4.fc40.aarch64" /var/log/dnf.rpm.log   
#	2024-10-24T21:35:15+0200 SUBDEBUG Upgrade: cups-browsed-1:2.0.1-4.fc40.aarch64
#	2024-10-24T21:35:15+0200 INFO warning: /etc/cups/cups-browsed.conf created as /etc/cups/cups-browsed.conf.rpmnew
#
	local offline_timestamp
	local upgraded_packages
	local package
	local dnf_timestamp
	local offline_epoch
	local dnf_epoch
	local time_diff
	local config_reference
	local config_file
	# Extract the timestamp of the offline upgrade
	offline_timestamp=$(head -n 1 "$success" | awk '{print $1}')
	# Extract the list of upgraded packages
	upgraded_packages=$(grep -oP '(?<=Upgraded: ).*' "$success")

	# Loop through each upgraded package and compare with dnf.rpm.log
	while IFS= read -r package; do
	    # Find matching package in dnf.rpm.log within a 1-minute window
	    grep -A 1 -P "($package)" "$rpm_log" | while IFS= read -r dnf_entry; do
	        # Extract timestamp from dnf.rpm.log entry, removing any additional text
	        dnf_timestamp=$(echo "$dnf_entry" | awk '{print $1" "$2}' | sed 's/[^0-9T:+-]//g')

	        # Convert both timestamps to epoch for comparison
	        offline_epoch=$(date --date="$offline_timestamp" +%s)
	        dnf_epoch=$(date --date="$dnf_timestamp" +%s)

	        # Calculate time difference in seconds
	        time_diff=$((dnf_epoch - offline_epoch))
	        if [ "$time_diff" -ge -60 ] && [ "$time_diff" -le 60 ]; then
	            # Check if the next line contains an .rpmnew, .rpmsave, or .rpmorig reference
	            config_reference=$(grep -A 1 -P "$package" "$rpm_log" | grep -E "\.rpm(new|save|orig)")
	            if [ -n "$config_reference" ]; then
	                # Extract the full path of the .rpmnew, .rpmsave, or .rpmorig file
	                config_file=$(echo "$config_reference" | grep -oP '(?<=created as ).*\.(rpmnew|rpmsave|rpmorig)')
	                echo "- Nouveau fichier de configuration trouvé ($config_file) pour le paquet $package installé le $offline_timestamp." >> "$success"
				fi
	            break # Exit the loop after the first match to avoid duplication
	        fi
	    done
	done <<< "$upgraded_packages"
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
