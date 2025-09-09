#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_dashboard.sh -h <host> -u <user> -p <pass> -d <db_name>
# Dashboard per gestione manuale duplicati rilevati
# ==============================================================================
PG_CONTAINER=""
PG_USERNAME=""
PG_PASSWORD=""
PG_DATABASE=""

while getopts "h:u:p:d:" opt; do
  case $opt in
    h) PG_CONTAINER="$OPTARG" ;;
    u) PG_USERNAME="$OPTARG" ;;
    p) PG_PASSWORD="$OPTARG" ;;
    d) PG_DATABASE="$OPTARG" ;;
    \?) echo "Opzione non valida: -$OPTARG" >&2; exit 1 ;;
  esac
done

# Verifica parametri obbligatori
if [[ -z "$PG_CONTAINER" || -z "$PG_USERNAME" || -z "$PG_PASSWORD" || -z "$PG_DATABASE" ]]; then
    echo "Uso: $0 -h <container> -u <user> -p <password> -d <database>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Funzione per verificare connessione database
check_database() {
    if ! docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
        echo "ERRORE: Impossibile connettersi al database PostgreSQL"
        exit 1
    fi
}

# Funzione per recuperare prossimo duplicato da processare
get_next_duplicate() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$script_dir/pg_mpi_sql_duplicates_read_next.sh" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE"
}

# Funzione per visualizzare confronto duplicati
show_duplicate_comparison() {
    local duplicate_data="$1"
    
    if [[ -z "$duplicate_data" ]]; then
        echo "Nessun duplicato da processare trovato!"
        return 1
    fi
    
    # Parse dei dati (assumendo formato separato da |)
    IFS='|' read -r duplicate_id id_paziente_a id_paziente_b score stato priorita \
                   nome_a secondo_nome_a data_nascita_a sesso_a luogo_nascita_a cf_hash_a cellulare_a telefono_a email_a \
                   nome_b secondo_nome_b data_nascita_b sesso_b luogo_nascita_b cf_hash_b cellulare_b telefono_b email_b \
                   <<< "$duplicate_data"
    
    # Rimuovi spazi extra
    duplicate_id=$(echo "$duplicate_id" | tr -d ' ')
    id_paziente_a=$(echo "$id_paziente_a" | tr -d ' ')
    id_paziente_b=$(echo "$id_paziente_b" | tr -d ' ')
    score=$(echo "$score" | tr -d ' ')
    stato=$(echo "$stato" | tr -d ' ')
    priorita=$(echo "$priorita" | tr -d ' ')
    
    clear
    echo "========================================"
    echo "🔍 DUPLICATO RILEVATO (Score: ${score}%)"
    echo "========================================"
    echo ""
    printf "%-30s │ %-30s\n" "PAZIENTE A (ID: $id_paziente_a)" "PAZIENTE B (ID: $id_paziente_b)"
    echo "──────────────────────────────────────────────────────────────"
    printf "%-30s │ %-30s\n" "Nome: $(echo $nome_a | tr -d ' ')" "Nome: $(echo $nome_b | tr -d ' ')"
    printf "%-30s │ %-30s\n" "Secondo nome: $(echo $secondo_nome_a | tr -d ' ')" "Secondo nome: $(echo $secondo_nome_b | tr -d ' ')"
    printf "%-30s │ %-30s\n" "Data nascita: $(echo $data_nascita_a | tr -d ' ')" "Data nascita: $(echo $data_nascita_b | tr -d ' ')"
    printf "%-30s │ %-30s\n" "Sesso: $(echo $sesso_a | tr -d ' ')" "Sesso: $(echo $sesso_b | tr -d ' ')"
    printf "%-30s │ %-30s\n" "Luogo nascita: $(echo $luogo_nascita_a | tr -d ' ')" "Luogo nascita: $(echo $luogo_nascita_b | tr -d ' ')"
    printf "%-30s │ %-30s\n" "CF Hash: $(echo $cf_hash_a | tr -d ' ' | cut -c1-10)..." "CF Hash: $(echo $cf_hash_b | tr -d ' ' | cut -c1-10)..."
    printf "%-30s │ %-30s\n" "Cellulare: $(echo $cellulare_a | tr -d ' ')" "Cellulare: $(echo $cellulare_b | tr -d ' ')"
    printf "%-30s │ %-30s\n" "Telefono: $(echo $telefono_a | tr -d ' ')" "Telefono: $(echo $telefono_b | tr -d ' ')"
    printf "%-30s │ %-30s\n" "Email: $(echo $email_a | tr -d ' ')" "Email: $(echo $email_b | tr -d ' ')"
    echo ""
    echo "Stato: $stato | Priorità: $priorita"
    echo ""
    echo "========================================"
    echo "SCEGLI AZIONE:"
    echo "========================================"
    echo "1) 🔗 CONFERMA DUPLICATO - Crea cluster anagrafici"
    echo "2) ❌ RESPINGI - Non sono la stessa persona"
    echo "3) 🔄 RIMANDA - Richiede ulteriori verifiche"
    echo "4) 🚫 BLACKLIST - Non proporre più questa coppia"
    echo "5) ⏭️  SALTA - Passa al prossimo duplicato"
    echo "6) 📊 DETTAGLI - Mostra score dettagliato"
    echo "7) ❌ ESCI"
    echo ""
    
    # Export variabili per gli script
    export DUPLICATE_ID="$duplicate_id"
    export ID_PAZIENTE_A="$id_paziente_a"
    export ID_PAZIENTE_B="$id_paziente_b"
    export DUPLICATE_SCORE="$score"
}

# Funzione per processare scelta utente
process_user_choice() {
    local choice="$1"
    
    case $choice in
        1)
            echo "Creazione cluster anagrafici..."
            set +e
            "$SCRIPT_DIR/pg_mpi_dashboard_merge.sh" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE" -i "$DUPLICATE_ID"
            set -e
            ;;
        2)
            echo "Respingimento duplicato..."
            set +e
            "$SCRIPT_DIR/pg_mpi_dashboard_reject.sh" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE" -i "$DUPLICATE_ID"
            set -e
            ;;
        3)
            echo "Posticipazione duplicato..."
            set +e
            "$SCRIPT_DIR/pg_mpi_dashboard_postpone.sh" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE" -i "$DUPLICATE_ID"
            set -e
            ;;
        4)
            echo "Aggiunta a blacklist..."
            set +e
            "$SCRIPT_DIR/pg_mpi_dashboard_blacklist.sh" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE" -i "$DUPLICATE_ID"
            set -e
            ;;
        5)
            echo "Saltando al prossimo duplicato..."
            return 0
            ;;
        6)
            echo "Visualizzazione dettagli score..."
            set +e  # Disabilita exit su errore temporaneamente
            "$SCRIPT_DIR/pg_mpi_dashboard_details.sh" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE" -i "$DUPLICATE_ID"
            set -e  # Riabilita exit su errore
            echo ""
            read -p "Premi INVIO per continuare..."
            return 2  # Ritorna alla stessa schermata
            ;;
        7)
            echo "Uscita dalla dashboard..."
            exit 0
            ;;
        *)
            echo "Scelta non valida. Riprova."
            sleep 1
            return 2  # Ritorna alla stessa schermata
            ;;
    esac
    
    return 1  # Passa al prossimo duplicato
}

# Funzione principale dashboard
main_dashboard() {
    echo "========================================"
    echo "PostgreSQL MPI - Dashboard Duplicati"
    echo "========================================"
    echo "Container: $PG_CONTAINER"
    echo "Database: $PG_DATABASE"
    echo "========================================"
    echo ""
    
    check_database
    
    # Loop principale dashboard
    while true; do
        # Recupera prossimo duplicato
        duplicate_data=$(get_next_duplicate)
        
        if [[ -z "$duplicate_data" ]] || [[ "$duplicate_data" =~ ^[[:space:]]*$ ]]; then
            echo "🎉 Nessun duplicato da processare!"
            echo "Tutti i duplicati sono stati elaborati."
            exit 0
        fi
        
        # Mostra confronto e menu
        while true; do
            show_duplicate_comparison "$duplicate_data"
            
            read -p "Scelta [1-7]: " user_choice
            
            process_user_choice "$user_choice"
            choice_result=$?
            
            if [[ $choice_result -eq 0 ]]; then
                # Salta al prossimo
                break
            elif [[ $choice_result -eq 1 ]]; then
                # Processa azione e passa al prossimo
                echo ""
                read -p "Premi INVIO per continuare al prossimo duplicato..."
                break
            fi
            # choice_result = 2 significa rimani sulla stessa schermata
        done
    done
}

# Avvio dashboard
main_dashboard