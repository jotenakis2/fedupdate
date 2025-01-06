#!/bin/bash
set -ueo pipefail
# variables globales
indicator_file="$HOME/.offline-upgrade"
datadir="$HOME/.local/share/fedupdate"
success="$datadir/offline_upgrade.success.log"
failure="$datadir/offline_upgrade.failure.log"
bigerror="$datadir/$(basename "$0").error"
icon="/usr/share/swcatalog/icons/fedora/128x128/org.mageia.dnfdragora.png"
dnf="/usr/bin/dnf"
dnfver=""
################################################################################################################################
#            SOUS-ROUTINES DU SCRIPT                                                                                           #
################################################################################################################################
CHECK_DNF_VERSION() {
    local version_info=""
    version_info=$($dnf --version 2>/dev/null || echo "unknown")
    if echo "$version_info" | grep -q "^4\."; then
        echo "dnf4"
        return 0
    elif echo "$version_info" | grep -q "5\."; then
        echo "dnf5"
        return 0
    else
        echo "Unable to determine DNF version." >> "$bigerror"
        return 1
    fi
}
################################################################################################################################
SEND-EMAIL() {
	local liste="$2"
	local subject="$1"
	export USERLOCAL="root"
	if EXISTS mail; then
		echo "DEBUG: Envoi d'un email à $email..."
		mail -s "[$host] $subject" "$email" < "$liste" || true
		return 0
	else
		echo "DEBUG: impossible d'envoyer un email, command \"mail\" manquante..." | tee -a "$bigerror"
		return 1
	fi
}
################################################################################################################################
FORMAT-DATE() {
    local formatted_date=""
    formatted_date=$(date -d "$1" "+%d %B %Y à %Hh%Mmin%Ssec" 2>/dev/null || echo "Invalid date")
    echo "$formatted_date"
    return 0
}
################################################################################################################################
CHECK-NEW-CONF-FILE() { # recherche de fichiers rpmnew/rpmsave crées par une maj
    # Récupérer et convertir le timestamp de la mise à jour hors-ligne
    local rpm_log="/var/log/dnf.rpm.log"
    local offline_timestamp=""
    local -i offline_epoch=0
    local line=""
    local line_timestamp=""
    local -i line_epoch=0
    local -i time_diff=0
    local config_file=""

    if [[ ! -f "$success" ]]; then
        echo "Fichier log success absent" >> "$bigerror"
        return 1
    fi

    offline_timestamp=$(head -n 1 "$success" | awk '{print $1}' || true)
    offline_epoch=$(date --date="$offline_timestamp" +%s 2>/dev/null || echo 0)
    # Rechercher toutes les lignes dans dnf.rpm.log créant un fichier rpmnew, rpmsave, ou rpmorig
    grep -E "\.rpm(new|save|orig)" "$rpm_log" | while IFS= read -r line; do
        # Vérifier si la ligne contient un timestamp
        line_timestamp=$(echo "$line" | awk '{print $1" "$2}' | sed 's/[^0-9T:+-]//g')
        if [[ -z "$line_timestamp" || ! "$line_timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
            #Pas de timestamp valide trouvé, on passe
            continue
        fi
        # Convertir le timestamp et gérer les erreurs
        line_epoch=$(date --date="$line_timestamp" +%s 2>/dev/null || {
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
    return 0
}
################################################################################################################################
POSTUPGRADEDNF4() {
	local log_file="/var/log/dnf.log"
	local last_result=""
	local update_time=""
	local readable_time=""
	#
	if [[ -f "$log_file" ]]; then
		last_result=$(awk '{lines[NR] = $0} END {for (i = NR; i > 0; i--) print lines[i]}' "$log_file" | grep -m 1 -E 'Complete!|Terminé|err' || true)
	    update_time=$(echo "$last_result" | awk '{print $1}' || true)
	    readable_time=$(FORMAT-DATE "$update_time")
	    last_result=${last_result,,}
	    if [[ $last_result == *"complete"* || $last_result == *"terminé"* ]]; then
	        grep "${update_time}" "$log_file" | awk 'NR==1 {print $1, $3, $4, $5, $6, $7, $8, $9} NR>1 {$1=$2=""; print $0}' > "$success"
	        CHECK-NEW-CONF-FILE || true
	        notify-send -i "$icon" --app-name "Mise à jour hors-ligne" "Effectuée correctement le $readable_time." "Fichier de log : $success"
         	if [ "$notif_email" = "yes" ]; then
            	SEND-EMAIL "Mise à jour avec succès" "$success"
            fi
	    elif [[ $last_result == *"err"* ]]; then
	        grep "${update_time}" "$log_file" > "$failure"
	        notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "En échec le $readable_time." "Fichier de log : $failure"
        	if [ "$notif_email" = "yes" ]; then
            	SEND-EMAIL "Mise à jour en échec" "$failure"
            fi
	    else
	        grep "${update_time}" "$log_file" > "$failure"
	        notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "Résultat inconnu." "Fichier de log : $failure"
        	if [ "$notif_email" = "yes" ]; then
            	SEND-EMAIL "Mise à jour en probable échec - A vérifier" "$failure"
            fi
	    fi
		return 0
	else
		echo "Log file $log_file not found" >> "$bigerror"
		return 1
	fi
}
################################################################################################################################
POSTUPGRADEDNF5() {
    local log_dir=""
    log_dir="/var/log"
    local log_files=()
    local log_file=""
    log_files=("$log_dir/dnf5.log.5" "$log_dir/dnf5.log.4" "$log_dir/dnf5.log.3" "$log_dir/dnf5.log.2" "$log_dir/dnf5.log.1" "$log_dir/dnf5.log")
    local -i pid_dnf=0
    local dnf5launch=""
    local first_date=""
    local last_date=""
    local first_date_readable=""
    local last_date_readable=""
    local last_three_entries=""
    local start_timestamp=""
    local tmp_filtered_log=""
    local reverse_tmp_filtered_log=""
    local temp_combined=""
    tmp_filtered_log="$HOME/.cache/offlineupgrade-filteredlog.log"
    reverse_tmp_filtered_log="$HOME/.cache/offlineupgrade-filteredlog.tmp"
    temp_combined="$HOME/.cache/temp-combinedlog.log"
    local -i start_epoch=0

    # init files
    true > "$tmp_filtered_log"
    true > "$reverse_tmp_filtered_log"
    true > "$temp_combined"
    rm -f "$failure" "$success"
    # copy log files into a single one in a safe place ($HOME/.cache)
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
        	echo "DEBUG: concatenate - $log_file"
            cat "$log_file" >> "$temp_combined"
        fi
    done
    sleep 1

    # Search for the last occurrence of "dnf5 offline _execute" in the logs
    dnf5launch=$(tac "$temp_combined" 2>/dev/null | \
        awk '/dnf5 offline _execute|dnf offline _execute/ {print; exit}' || true)

    if [[ -z "$dnf5launch" ]]; then
        echo "DEBUG: Aucune commande \"dnf5 offline _execute\" n'a été trouvée dans les logs" | tee -a "$bigerror"
        return 1
    fi

    # Debug: Log the extracted dnf5launch
    echo "DEBUG: Extracted dnf5launch: $dnf5launch"

    # Extract PID and timestamp from the launch line
    pid_dnf=$(echo "$dnf5launch" | grep -o '\[[0-9]\+]' | tr -d '[]' || true)
    start_timestamp=$(echo "$dnf5launch" | awk '{print $1}')
    start_epoch=$(date --date="$start_timestamp" +%s 2>/dev/null || echo 0)

    # Debug: Log PID and timestamp
    echo "DEBUG: PID: $pid_dnf, Timestamp: $start_timestamp, Epoch: $start_epoch"

    if (( pid_dnf > 0 )); then
		flock -x "$temp_combined" sh -c "												# flock -x to ensure only this script is touching temp_combined
	  		awk -v pid='${pid_dnf}' -v start_epoch='${start_epoch}' '
		        {
		        	# Store each line in an array with line numbers as keys
					lines[NR] = \$0
		        }
		        END {
		            for (i = NR; i > 0; i--) {											# we go through all the lines starting from the end.
		                if (lines[i] ~ \"\\\\[\" pid \"\\\\]\") { 						# the line match with pid
		                    line_timestamp = \$1										# we extract timestamp
		                    cmd = \"date --date=\\\"\" line_timestamp \"\\\" +%s\"		# we convert to epoch
		                    if ((cmd | getline line_epoch) > 0) {						# the cmd date returns 1 when successfull
		                        close(cmd)
		                        if (line_epoch >= start_epoch) {						# if current line is older or equal to start time
		                            print lines[i]
		                        }
		                    } else {													# it fails to convert
		                        continue												# then we go to the next line.
		                    }
		                }
		                if (lines[i] ~ /offline _execute/) {							# the line contains offline _execute,
							break														# we exit the for loop
		                }
		            }
		        }
			' '$temp_combined' > '$reverse_tmp_filtered_log'
		"
	    # Reverse the filtered output to restore chronological order
		awk '
			{
				 lines[NR] = $0  # Store each line in an array
			}
			END {
				for (i = NR; i > 0; i--) {  # Print lines in reverse order
					print lines[i]
				}
			}
			' "$reverse_tmp_filtered_log" > "$tmp_filtered_log"
	    rm -f "$reverse_tmp_filtered_log" "$temp_combined"

        if ! grep -Eq "INFO DNF5 (finished|a terminé)" "$tmp_filtered_log"; then
            echo "DEBUG: Fin de mise à jour 'INFO DNF5 finished' ou 'INFO DNF5 a terminé' introuvable pour le PID $pid_dnf." | tee -a "$bigerror"
        fi

        # Extract first and last timestamps from the combined log
        first_date=$(grep "\[$pid_dnf\]" "$tmp_filtered_log" | head -n 1 | awk '{print $1}' || true)
        first_date_readable=$(FORMAT-DATE "$first_date")
        echo "DEBUG: Début de mise à jour hors-ligne : $first_date_readable"

        last_date=$(grep "\[$pid_dnf\]" "$tmp_filtered_log" | tail -n 1 | awk '{print $1}' || true)
        last_date_readable=$(FORMAT-DATE "$last_date")
        echo "DEBUG: Fin de mise à jour hors-ligne : $last_date_readable"

        # Capture the last three entries from the combined log
        last_three_entries=$(tail -n 3 "$tmp_filtered_log" || true)
        # Debug: Log the extracted last_three_entries
        echo "DEBUG: Extracted last_three_entries: "
        echo "$last_three_entries"

        # Final status checks
        if grep -q "Transaction complete!" "$tmp_filtered_log" && \
           grep -Eq "INFO DNF5 (finished|a terminé)" "$tmp_filtered_log"; then
            echo "DEBUG: LA MISE À JOUR HORS-LIGNE A ÉTÉ ÉXÉCUTÉE CORRECTEMENT"
            echo "DEBUG: see $success"
            {
                echo "Début de mise à jour hors-ligne : $first_date_readable"
                echo "Fin de mise à jour hors-ligne : $last_date_readable"
                echo "==> LA MISE À JOUR HORS-LIGNE A ÉTÉ ÉXÉCUTÉE CORRECTEMENT <=="
                echo
                echo "--------------------------------"
                echo "$dnf5launch"
                grep "INFO.*install" "$tmp_filtered_log" | grep -v start || true
                echo "$last_three_entries"
                echo "--------------------------------"
                echo
                echo "Erreurs éventuelles :"
                grep -i "error" "$tmp_filtered_log" || echo "Aucune erreur trouvée"
                echo
            } >> "$success"
            CHECK-NEW-CONF-FILE || true # recherche fichier rpmnew/rpmsave
            notify-send -i "$icon" --app-name "Mise à jour hors-ligne" \
                        "Effectuée correctement le $first_date_readable." "Fichier de log : $success"
            if [ "$notif_email" = "yes" ]; then
            	SEND-EMAIL "Mise à jour avec succès" "$success"
            fi
        else
        	echo "DEBUG: LA MISE À JOUR HORS-LIGNE SEMBLE AVOIR ÉCHOUÉ"
         	echo "DEBUG: see $failure"
            {
                echo "Début de mise à jour hors-ligne : $first_date_readable"
                echo "Fin de mise à jour hors-ligne : $last_date_readable"
                echo "==> LA MISE À JOUR HORS-LIGNE SEMBLE AVOIR ÉCHOUÉ  <=="
                echo "$last_three_entries"
                echo
                echo "--------------------------------"
                cat "$tmp_filtered_log"
                echo "--------------------------------"
                echo "Erreurs éventuelles :"
                grep -i "error" "$tmp_filtered_log" || echo "Aucune erreur trouvée"
                echo
            } >> "$failure"
            notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" \
                        "En échec le $last_date_readable." "Fichier de log : $failure"
            if [ "$notif_email" = "yes" ]; then
               	SEND-EMAIL "Mise à jour en probable échec - A vérifier" "$failure"
            fi
        fi
        return 0
    else
        echo "DEBUG: Erreur de récupération du PID de la dernière commande dnf5 offline _execute" | tee "$bigerror"
        return 1
    fi
}
################################################################################################################################
WAITFORDBUS() {
    local -i attempt=0
    local -i max_attempts=9
    local -i sleep_time=10
    while ! dbus-send --session --dest=org.freedesktop.Notifications --type=method_call \
             /org/freedesktop/Notifications org.freedesktop.Notifications.GetCapabilities >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "DEBUG : Avertissement : D-Bus n'est toujours pas prêt après $attempt tentatives. Continuation du script quand même." | tee -a "$bigerror"
            return 1
        fi
        sleep "$sleep_time"
    done
    if [ "$attempt" -eq 0 ]; then
        echo "DEBUG: dbus est prêt."
    elif [ "$attempt" -lt "$max_attempts" ]; then
        echo "DEBUG: dbus est prêt après $attempt boucle(s) d'attente de ${sleep_time}s."
    fi
    return 0
}
################################################################################################################################
HOSTNAME() {
    host=$(/usr/bin/hostnamectl --transient 2>/dev/null) || true
    [ -n "$host" ] || host=$(/usr/bin/hostname 2>/dev/null) || true
    [ -n "$host" ] || host=$(/usr/bin/uname -n 2>/dev/null) || true
    [ -n "$host" ] || host="unknown"
    return 0
}
################################################################################################################################
EXISTS() {
	unalias "$1" >/dev/null 2>&1 || true
	command -v "$1" >/dev/null 2>&1
}
################################################################################################################################


################################################################################################################################
#                   CORPS DU SCRIPT                                                                                            #
################################################################################################################################
if [ -f "$indicator_file" ]; then 						# le script est lancé que si le fichier indicator est présent.
	notif_email=""
	email=""
	HOSTNAME || true
    if grep -q "yes" "$HOME/.offline-upgrade"; then		# la notif_email est activée.
    	# shellcheck source=/dev/null
     	source "$HOME/.config/fedupdate/config.rc"			# sourcing fichier de conf pour récupérer email address.
      	notif_email="yes"
    fi
	rm -f "$bigerror"
	dnf="$(head -1 "$indicator_file")" 						# on récupère le chemin complet de dnf utilisée lors de la mise à jour hors-ligne (/usr/bin/dnf ou /usr/bin/dnf4 ou /usr/bin/dnf5).
	dnfver="$(CHECK_DNF_VERSION || echo "unknown")"  	# on en déduit la version de dnf utilisée lors de la mise à jour hors-ligne.
	WAITFORDBUS || true 								# On attend que dBUS soit dispo pour pouvoir lancer une notif système.
	if [[ "$dnfver" == "dnf4" ]]; then 					# dnf version 4.
		POSTUPGRADEDNF4 || true
	elif [[ "$dnfver" == "dnf5" ]]; then  				# dnf version 5.
		POSTUPGRADEDNF5 || true
	else
		echo "DEBUG: Unsupported DNF version: $dnfver" | tee -a "$bigerror"
	fi
	rm -f "$indicator_file" 							# on efface le fichier indicator pour que le script ne se lance pas au prochain démarrage.
fi
exit 0
