#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_install.sh -h <host> -u <user> -p <pass> -d <db_name>
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILES=(
    "pg_mpi_install_v6.sql"
    "pg_mpi_install_sp_insert_v6.sql"
    "pg_mpi_install_sp_update_v6.sql"
    "pg_mpi_install_sp_delete_v6.sql"
    "pg_mpi_install_sp_restore_v6.sql"
    "pg_mpi_install_sp_duplicates_v6.sql"
)
CSV_FILES=(
    "pg_mpi_install_domini.csv"
)

# Controlla se il container PostgreSQL è in esecuzione
check_container() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^${PG_CONTAINER}$"; then
        echo "ERRORE: Container PostgreSQL '${PG_CONTAINER}' non trovato"
        exit 1
    fi
}

# Controlla se i file SQL esistono
check_sql_files() {
    for sql_file in "${SQL_FILES[@]}"; do
        local file_path="${SCRIPT_DIR}/${sql_file}"
        if [[ ! -f "$file_path" ]]; then
            echo "ERRORE: File SQL non trovato: $file_path"
            exit 1
        fi
    done
}

# Controlla se i file CSV esistono
check_csv_files() {
    for csv_file in "${CSV_FILES[@]}"; do
        local file_path="${SCRIPT_DIR}/${csv_file}"
        if [[ ! -f "$file_path" ]]; then
            echo "ERRORE: File CSV non trovato: $file_path"
            exit 1
        fi
    done
}

# Testa la connessione al database PostgreSQL
test_connection() {
    echo "Testando connessione al database..."
    if ! docker exec -i "$PG_CONTAINER" env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
        echo "ERRORE: Impossibile connettersi al database PostgreSQL"
        exit 1
    fi
    echo "✓ Connessione al database riuscita"
}

# Esegue un file SQL nel container PostgreSQL
execute_sql_file() {
    local sql_file="$1"
    local file_path="${SCRIPT_DIR}/${sql_file}"
    
    echo "Esecuzione file SQL: $sql_file"
    echo "Debug: Eseguendo docker exec su container $PG_CONTAINER..."
    
    # Esegui usando cat invece di redirect
    local docker_exit_code=0
    set +e  # Disabilita temporaneamente exit su errore
    cat "$file_path" | docker exec -i "$PG_CONTAINER" env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -v ON_ERROR_STOP=1
    docker_exit_code=$?
    set -e  # Riabilita exit su errore
    
    echo "Debug: docker exec ha restituito exit code: $docker_exit_code"
    
    if [[ $docker_exit_code -eq 0 ]]; then
        echo "✓ File $sql_file eseguito con successo"
        sleep 0.1  # Pausa per debug
        return 0
    else
        echo "✗ Errore durante l'esecuzione del file $sql_file (exit code: $docker_exit_code)"
        return 1
    fi
}

# Carica un file CSV nel container PostgreSQL
load_csv_file() {
    local csv_file="$1"
    local table_name="$2"
    local file_path="${SCRIPT_DIR}/${csv_file}"
    
    echo "Caricamento file CSV: $csv_file -> $table_name"
    
    # Copia il file CSV nel container
    if ! docker cp "$file_path" "$PG_CONTAINER:/tmp/$csv_file"; then
        echo "✗ Errore durante la copia del file $csv_file nel container"
        return 1
    fi
    
    # Crea una tabella temporanea e usa INSERT con ON CONFLICT per gestire l'idempotenza
    if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
        -- Crea tabella temporanea
        CREATE TEMP TABLE temp_$table_name (LIKE $table_name INCLUDING DEFAULTS);
        
        -- Carica dati nella tabella temporanea
        COPY temp_$table_name (codice, nome, nome_breve, data_inizio, data_fine, attivo, creato_da)
        FROM '/tmp/$csv_file'
        WITH (
            FORMAT csv,
            DELIMITER ';',
            QUOTE '\"',
            HEADER true,
            NULL '\\N'
        );
        
        -- Inserisci con gestione conflitti
        INSERT INTO $table_name (codice, nome, nome_breve, data_inizio, data_fine, attivo, creato_da)
        SELECT codice, nome, nome_breve, data_inizio, data_fine, attivo::BOOLEAN, creato_da
        FROM temp_$table_name
        ON CONFLICT (codice) DO NOTHING;
        
        -- Rimuovi tabella temporanea
        DROP TABLE temp_$table_name;
    "; then
        echo "✓ File $csv_file caricato con successo in $table_name"
        # Rimuovi il file temporaneo dal container
        docker exec "$PG_CONTAINER" rm -f "/tmp/$csv_file" 2>/dev/null || true
        return 0
    else
        echo "✗ Errore durante il caricamento del file $csv_file"
        # Rimuovi il file temporaneo dal container anche in caso di errore
        docker exec "$PG_CONTAINER" rm -f "/tmp/$csv_file" 2>/dev/null || true
        return 1
    fi
}

# Verifica l'installazione controllando alcune tabelle chiave
verify_installation() {
    echo "Verifica installazione..."
    
    local tables_check=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name IN ('anagrafiche_pazienti', 'dati_sensibili_pazienti', 'dati_contatto_residenza');
    " -t 2>/dev/null | tr -d ' ')
    
    if [[ "$tables_check" -eq "3" ]]; then
        echo "✓ Tabelle principali create correttamente"
    else
        echo "⚠ Alcune tabelle potrebbero non essere state create correttamente"
    fi
    
    local procedures_check=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
        SELECT COUNT(*) FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name IN (
            'sp_insert_anagrafica_transazionale', 
            'sp_update_anagrafica_transazionale', 
            'sp_delete_anagrafica_transazionale',
            'sp_restore_anagrafica_transazionale',
            'sp_check_restore_eligibility',
            'sp_scan_duplicati_post_insert',
            'sp_process_duplicate_scan_batch'
        );
    " -t 2>/dev/null | tr -d ' ')
    
    if [[ "$procedures_check" -eq "7" ]]; then
        echo "✓ Stored procedures create correttamente"
    else
        echo "⚠ Alcune stored procedures potrebbero non essere state create correttamente ($procedures_check/7)"
    fi
    
    local domains_check=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
        SELECT COUNT(*) FROM domini_sanitari WHERE attivo = TRUE;
    " -t 2>/dev/null | tr -d ' ')
    
    if [[ "$domains_check" -gt "0" ]]; then
        echo "✓ Domini sanitari caricati correttamente ($domains_check trovati)"
    else
        echo "⚠ Nessun dominio sanitario trovato"
    fi
}

main() {
    echo "========================================"
    echo "PostgreSQL Anagrafiche Installation"
    echo "========================================"
    
    # Esporta la password per PostgreSQL
    export PGPASSWORD="$PG_PASSWORD"
    
    # Verifiche preliminari
    check_container
    check_sql_files
    check_csv_files
    test_connection
    
    echo "Inizio installazione schema e stored procedures..."
    
    # Esegui prima il file principale
    echo "1/6 - Installazione schema principale..."
    if ! execute_sql_file "pg_mpi_install_v6.sql"; then
        echo "Errore nell'installazione dello schema principale"
        exit 1
    fi
    
    # Esegui gli script separati per le stored procedures
    local scripts=(
        "pg_mpi_install_sp_insert.sh"
        "pg_mpi_install_sp_update.sh" 
        "pg_mpi_install_sp_delete.sh"
        "pg_mpi_install_sp_restore.sh"
        "pg_mpi_install_sp_duplicates.sh"
    )
    
    local count=2
    for script in "${scripts[@]}"; do
        echo "$count/6 - Eseguendo $script..."
        if ! ./"$script" -h "$PG_CONTAINER" -u "$PG_USERNAME" -p "$PG_PASSWORD" -d "$PG_DATABASE"; then
            echo "Errore durante l'esecuzione di $script"
            exit 1
        fi
        ((count++))
    done
    
    # Carica i file CSV
    echo "Caricamento dati iniziali da file CSV..."
    if load_csv_file "pg_mpi_install_domini.csv" "domini_sanitari"; then
        echo "✓ Dati domini sanitari caricati correttamente"
    else
        echo "✗ Errore durante il caricamento dei domini sanitari"
        exit 1
    fi
    
    # Verifica finale
    verify_installation
    
    echo "========================================"
    if [[ $success_count -eq $total_files ]]; then
        echo "INSTALLAZIONE COMPLETATA CON SUCCESSO!"
        echo "File elaborati: $success_count/$total_files"
        echo "Database: $PG_DATABASE"
        echo "Container: $PG_CONTAINER"
    else
        echo "INSTALLAZIONE PARZIALMENTE FALLITA"
        echo "File elaborati con successo: $success_count/$total_files"
        exit 1
    fi
    echo "========================================"
}

main