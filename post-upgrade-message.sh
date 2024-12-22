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
    if echo "$version_info" | grep -q "4\."; then
        echo "dnf4"
    elif echo "$version_info" | grep -q "5\."; then
        echo "dnf5"
    else
        echo "Unable to determine DNF version." >> "$bigerror"
        return 1
    fi
}
################################################################################################################################
FORMAT-DATE() {
    local formatted_date=""
    formatted_date=$(date -d "$1" "+%d %B %Y à %Hh%Mmin%Ssec" 2>/dev/null || echo "Invalid date")
    echo "$formatted_date"
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
	    elif [[ $last_result == *"err"* ]]; then
	        grep "${update_time}" "$log_file" > "$failure"
	        notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "En échec le $readable_time." "Fichier de log : $failure"
	    else
	        grep "${update_time}" "$log_file" > "$failure"
	        notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "Résultat inconnu." "Fichier de log : $failure"
	    fi
	else
		echo "Log file $log_file not found" >> "$bigerror"
	fi
}
################################################################################################################################
POSTUPGRADEDNF5() {
	local log_dir="/var/log"
	local log_file_base="dnf5.log"
	local log_file=""
	local -i pid_dnf=0
	local dnf5launch=""
	local first_date=""
	local last_date=""
	local first_date_readable=""
	local last_date_readable=""
	local last_three_entries=""
	local tmp_combined_log="$HOME/.cache/offlineupgrade-combinedlog.log"
	local line=""
	local line_timestamp=""
	local -i line_epoch=0
	local start_timestamp=""
	local -i start_epoch=""
	echo > "$tmp_combined_log"
	chmod 666 "$tmp_combined_log" || true
	rm -f "$failure" "$success"
	# Recherche de la commande 'dnf5 offline _execute' dans les logs dnf5.log, dnf5.log.1, etc. jusqu'à .5
	# log_file contient le nom du fichier où il aura trouvé la commande.
    for log_file in "$log_dir/$log_file_base"{,.{1..5}}; do
        if [[ -f "$log_file" ]]; then
            dnf5launch=$(awk '{lines[NR] = $0} END {for (i = NR; i > 0; i--) if (lines[i] ~ /dnf5 offline _execute|dnf offline _execute/) {print lines[i]; exit}}' "$log_file" || true)
            if [[ -n "$dnf5launch" ]]; then
                break
            fi
        fi
    done
    if [[ -z "$dnf5launch" ]]; then
        echo "Aucune commande \"dnf5 offline _execute\" n a été trouvée dans les logs" | tee -a "$bigerror"
        return 1
    fi
	# Extract PID and timestamp from the launch line
	pid_dnf=$(echo "$dnf5launch" | grep -o '\[[0-9]\+]' | tr -d '[]' || true)
	start_timestamp=$(echo "$dnf5launch" | awk '{print $1}')
	start_epoch=$(date --date="$start_timestamp" +%s)
	if (( pid_dnf > 0 )); then
		# Combiner toutes les entrées de log correspondantes au pid trouvé (+ timestamp cohérent) dans un fichier temporaire
		cat "$log_dir/$log_file_base"{,.{1..5}} | awk -v pid="[$pid_dnf]" -v start_epoch="$start_epoch" '
			{
			    # Extract the timestamp directly from $1
			    line_timestamp = $1

			    # Convert the timestamp to epoch
			    cmd = "date --date=\"" line_timestamp "\" +%s"
			    cmd | getline line_epoch
			    close(cmd)

			    # Compare line_epoch to start_epoch
			    if (line_epoch >= start_epoch && $0 ~ pid) {
			        print
			        if ($0 ~ /INFO DNF5 (finished|a terminé)/) {
         			   exit
               		}
			    }
			}
			' > "$tmp_combined_log"
		if ! grep -Eq "INFO DNF5 (finished|a terminé)" "$tmp_combined_log"; then
		    echo "Fin de mise à jour 'INFO DNF5 finished' ou 'INFO DNF5 a terminé' introuvable pour le PID $pid_dnf." >> "$bigerror"
		fi
		first_date="$(grep "\[$pid_dnf\]" "$tmp_combined_log" | head -n 1 | awk '{print $1}' || true)"
		first_date_readable="$(FORMAT-DATE "$first_date")"
		{ echo "$first_date"; echo; } > "$success"
		echo "Début de mise à jour hors-ligne : $first_date_readable" >> "$success"
#
		last_date="$(grep "\[$pid_dnf\]" "$tmp_combined_log" | tail -n 1 | awk '{print $1}' || true)"
		last_date_readable=$(FORMAT-DATE "$last_date")
		echo "Fin de mise à jour hors-ligne : $last_date_readable" >> "$success"
#
		last_three_entries=$(tail -n 3 "$tmp_combined_log" || true)
		if grep -q "Transaction complete!" "$tmp_combined_log" && grep -Eq "INFO DNF5 (finished|a terminé)" "$tmp_combined_log"; then
		    {
				echo "Fichier log : $log_file"
	            echo "==> LA MISE À JOUR HORS-LIGNE A ÉTÉ ÉXECUTÉE CORRECTEMENT <=="
	            echo
	            echo "--------------------------------"
	            echo "$dnf5launch"
	            grep "INFO.*install" "$tmp_combined_log" | grep -v start || true
	            echo "$last_three_entries"
	            echo "--------------------------------"
	            echo
				echo "Erreurs éventuelles :"
				grep -i "error" "$tmp_combined_log" || echo "Aucune erreur trouvée"
				echo
		    } >> "$success"
		    CHECK-NEW-CONF-FILE || true
		    notify-send -i "$icon" --app-name "Mise à jour hors-ligne" "Effectuée correctement le $first_date_readable." "Fichier de log : $success"
		else
		    {
				echo "Fichier log : $log_file"
	            echo "==> LA MISE À JOUR HORS-LIGNE SEMBLE AVOIR ÉCHOUÉ  <=="
	            echo "$last_three_entries"
	            echo
	            echo "--------------------------------"
	            cat "$tmp_combined_log"
	            echo "--------------------------------"
				echo "Erreurs éventuelles :"
				grep -i "error" "$tmp_combined_log" || echo "Aucune erreur trouvée"
				echo
			} >> "$failure"
		    notify-send -i "$icon" -u critical --app-name "Mise à jour hors-ligne" "En échec le $last_date_readable." "Fichier de log : $failure"
		fi
		return 0
	else
		echo "Erreur de récupération du PID de la dernière commande dnf5 offline _execute" | tee "$bigerror"
		return 1
	fi
}
################################################################################################################################
WAITFORDBUS() {
	local -i attempt=0
	local -i max_attempts=9
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
	echo "Attente état dbus : $attempt essai(s)"
}


################################################################################################################################
#                   CORPS DU SCRIPT                                                                                            #
################################################################################################################################
if [ -f "$indicator_file" ]; then
	rm -f "$bigerror"
	# on récupère la version de dnf utilisée lors de la mise à jour hors-ligne
	dnf="$(cat "$indicator_file")"
	dnfver="$(CHECK_DNF_VERSION || echo "unknown")"
	WAITFORDBUS || true
	if [[ "$dnfver" == "dnf4" ]]; then # dnf version 4
		POSTUPGRADEDNF4 || true
	elif [[ "$dnfver" == "dnf5" ]]; then  # dnf version 5
		POSTUPGRADEDNF5 || true
	else
		echo "Unsupported DNF version: $dnfver" >> "$bigerror"
	fi
	rm -f "$indicator_file"
fi
