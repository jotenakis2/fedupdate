#!/bin/bash
set -u
# variables globales
indicator_file="$HOME/.offline-upgrade"
success="$HOME/offline_upgrade.success.log"
failure="$HOME/offline_upgrade.failure.log"
rpm_log="/var/log/dnf.rpm.log"
scriptname="$(basename "$0")"
bigerror="$HOME/${scriptname}.error"
icon="/usr/share/swcatalog/icons/fedora/128x128/org.mageia.dnfdragora.png"
dnf="/usr/bin/dnf"
dnfver=""
declare -i attempt=0
declare -i max_attempts=9


################################################################################################################################
#            SOUS-ROUTINES DU SCRIPT                                                                                           #
################################################################################################################################
CHECK_DNF_VERSION() {
	local version_info=""
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
    local formatted_date=""
    formatted_date=$(date -d "$1" "+%d %B %Y à %Hh%Mmin%Ssec")
    echo "$formatted_date"
}
################################################################################################################################
CHECK-NEW-CONF-FILE() { # recherche de fichiers rpmnew/rpmsave crées par une maj
    # Récupérer et convertir le timestamp de la mise à jour hors-ligne
    local offline_timestamp=""
    declare -i offline_epoch=0
    local line=""
    local line_timestamp=""
    declare -i line_epoch=0
    declare -i time_diff=0
    local config_file=""
    offline_timestamp=$(head -n 1 "$success" | awk '{print $1}')
    offline_epoch=$(date --date="$offline_timestamp" +%s || echo 0)
    # Rechercher toutes les lignes dans dnf.rpm.log créant un fichier rpmnew, rpmsave, ou rpmorig
    grep -E "\.rpm(new|save|orig)" "$rpm_log" | while IFS= read -r line; do
        # Vérifier si la ligne contient un timestamp
        line_timestamp=$(echo "$line" | awk '{print $1" "$2}' | sed 's/[^0-9T:+-]//g')
        if [[ -z "$line_timestamp" || ! "$line_timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
            #Pas de timestamp valide trouvé, on passe
            continue
        fi
        # Convertir le timestamp et gérer les erreurs
        line_epoch=$(date --date="$line_timestamp" +%s || {
            echo "Erreur de conversion du timestamp pour la ligne : " >> "$bigerror"
            grep -A5 "$line" "$rpm_log" >> "$bigerror"
            # shellcheck disable=SC2106
            continue
        })
        # Calculer la différence de temps entre l'heure de mise à jour et l'heure des fichiers rpmnew/save trouvés
        time_diff=$((line_epoch - offline_epoch))
        time_diff=${time_diff#-} # Valeur absolue
        # Si la différence de temps est inférieure ou égale à 120 secondes, on considère le fichier comme pertinent
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
		sleep 10
	done
	sleep 5
	echo "Attente état du gestionnaire de notifications dbus : $attempt essai(s)"
#-------------
	if [ "$dnfver" = "dnf4" ]; then # dnf version 4
		log_file="/var/log/dnf.log"
		last_result=""
		update_time=""
		readable_time=""
		#
		last_result=$(awk '{lines[NR] = $0} END {for (i = NR; i > 0; i--) print lines[i]}' "$log_file" | grep -m 1 -E 'Complete!|Terminé|err')
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
		pid_dnf=""
		dnf5launch=""
		first_date=""
		last_date=""
		last_three_entries=""
		#
		dnf5launch=$(awk '{lines[NR] = $0} END {for (i = NR; i > 0; i--) print lines[i]}' "$log_file" | grep -m 1 -E 'dnf5 offline _execute|dnf offline _execute')
		pid_dnf=$(echo "$dnf5launch" | grep -o '\[[0-9]\+]' | tr -d '[]')
		if [[ -n "$pid_dnf" ]]; then
			first_date=$(FORMAT-DATE "$(grep -m 1 "\[$pid_dnf\]" "$log_file" | awk '{print $1}')")
			{ echo "$first_date"; echo; } > "$success"
			echo "Début de mise à jour hors-ligne : $first_date" | tee -a "$success"
			last_date=$(FORMAT-DATE "$(grep "\[$pid_dnf\]" "$log_file" | tail -n 1 | awk '{print $1}')")
			echo "Fin de mise à jour hors-ligne : $last_date" | tee -a "$success"
			last_three_entries=$(grep "\[$pid_dnf\]" "$log_file" | tail -n 3)
			if [[ "$last_three_entries" == *"Transaction complete!"* && "$last_three_entries" == *"DNF5 finished"* ]]; then
				{ echo "La mise à jour hors-ligne a été exécutée correctement";
				  echo;
				  echo "--------------------------------";
				  echo "$dnf5launch"
				  grep "${pid_dnf}.*INFO.*install" "$log_file" | grep -v start;
				  echo "$last_three_entries";
				  echo "--------------------------------";
				  grep -i "${pid_dnf}.*error" "$log_file";
				} >> "$success"
				CHECK-NEW-CONF-FILE
				notify-send -i "$icon" --app-name "Mise à jour hors-ligne" "Effectuée correctement le $first_date." "Fichier de log : $success"
			else
				{ echo "La mise à jour hors-ligne semble ne pas avoir été exécutée correctement";
				  echo "$last_three_entries";
				  echo;
				  echo "--------------------------------";
				  grep "$pid_dnf" "$log_file";
				  echo "--------------------------------";
				  grep -i "${pid_dnf}.*error" "$log_file";
				} >> "$failure"
				notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "En échec le $last_date." "Fichier de log : $failure"
			fi
		else
			echo "Erreur de récupération du PID de la dernière commande dnf5 offline _execute" | tee "$bigerror"
			grep -E '/usr/bin/dnf offline _execute|/usr/bin/dnf5 offline _execute' "$log_file" "$log_file".* >> "$bigerror" 2>&1
		fi
	fi
	# fin dnf version 5
#-------------
	rm -f "$indicator_file"
fi
