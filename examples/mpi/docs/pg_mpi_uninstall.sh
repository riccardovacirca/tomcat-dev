#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_uninstall.sh -h <host> -u <user> -p <pass> -d <db_name> [-f]
# ==============================================================================
PG_CONTAINER=""
PG_USERNAME=""
PG_PASSWORD=""
PG_DATABASE=""
FORCE_MODE=false

while getopts "h:u:p:d:f" opt; do
  case $opt in
    h) PG_CONTAINER="$OPTARG" ;;
    u) PG_USERNAME="$OPTARG" ;;
    p) PG_PASSWORD="$OPTARG" ;;
    d) PG_DATABASE="$OPTARG" ;;
    f) FORCE_MODE=true ;;
    \?) echo "Opzione non valida: -$OPTARG" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNINSTALL_SQL_FILE="pg_mpi_uninstall_v6.sql"

# Controlla se il container PostgreSQL è in esecuzione
check_container() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^${PG_CONTAINER}$"; then
        echo "ERRORE: Container PostgreSQL '${PG_CONTAINER}' non trovato"
        exit 1
    fi
}

# Controlla se il file SQL di uninstall esiste
check_sql_file() {
    local file_path="${SCRIPT_DIR}/${UNINSTALL_SQL_FILE}"
    if [[ ! -f "$file_path" ]]; then
        echo "ERRORE: File SQL di uninstall non trovato: $file_path"
        exit 1
    fi
}

# Testa la connessione al database PostgreSQL
test_connection() {
    if ! docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
        echo "ERRORE: Impossibile connettersi al database PostgreSQL"
        exit 1
    fi
}

# Richiesta conferma (solo se non in modalità force)
request_confirmation() {
    if [[ "$FORCE_MODE" == true ]]; then
        echo "Modalità force attivata: salto conferma utente"
        return 0
    fi
    
    echo ""
    echo "⚠️ ATTENZIONE: Questo script eliminerà TUTTE le tabelle e stored procedures del sistema anagrafico."
    echo "L'operazione è IRREVERSIBILE!"
    echo ""
    echo "Vuoi continuare? [y/N]:"
    read -r confirmation
    case "$confirmation" in
        y|Y|yes|YES)
            echo "Confermata rimozione del sistema anagrafico"
            ;;
        *)
            echo "Operazione annullata"
            exit 0
            ;;
    esac
}

# Esegue il file SQL di uninstall
execute_uninstall() {
    local file_path="${SCRIPT_DIR}/${UNINSTALL_SQL_FILE}"
    
    echo "Esecuzione script di uninstall: $UNINSTALL_SQL_FILE"
    
    if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" < "$file_path"; then
        echo "✓ Uninstall eseguito con successo"
        return 0
    else
        echo "✗ Errore durante l'esecuzione dell'uninstall"
        return 1
    fi
}

# Verifica rimozione
verify_uninstall() {
    echo "Verifica rimozione..."
    
    local remaining_tables=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name IN (
            'anagrafiche_pazienti', 
            'dati_sensibili_pazienti', 
            'dati_contatto_residenza',
            'duplicate_scan_queue',
            'candidati_duplicati'
        );
    " -t 2>/dev/null | tr -d ' ')
    
    local remaining_procedures=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
        SELECT COUNT(*) FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name IN (
            'sp_insert_anagrafica_transazionale', 
            'sp_update_anagrafica_transazionale', 
            'sp_delete_anagrafica_transazionale',
            'sp_scan_duplicati_post_insert',
            'sp_process_duplicate_scan_batch',
            'sp_cleanup_duplicate_scan_queue',
            'decrypt_sensitive_data'
        );
    " -t 2>/dev/null | tr -d ' ')
    
    if [[ "$remaining_tables" -eq "0" ]]; then
        echo "✓ Tabelle principali rimosse correttamente"
    else
        echo "⚠ Alcune tabelle potrebbero non essere state rimosse"
    fi
    
    if [[ "$remaining_procedures" -eq "0" ]]; then
        echo "✓ Stored procedures rimosse correttamente"
    else
        echo "⚠ Alcune stored procedures potrebbero non essere state rimosse"
    fi
}

main() {
    echo "========================================"
    echo "PostgreSQL Anagrafiche Uninstall"
    echo "========================================"
    
    # Verifiche preliminari
    check_container
    check_sql_file
    test_connection
    
    # Richiesta conferma
    request_confirmation
    
    echo "Avvio rimozione sistema anagrafico..."
    
    # Esecuzione uninstall
    if execute_uninstall; then
        echo ""
        verify_uninstall
        echo ""
        echo "========================================"
        echo "UNINSTALL COMPLETATO!"
        echo "Database: $PG_DATABASE"
        echo "Container: $PG_CONTAINER"
        echo ""
        echo "Per reinstallare: ./pg_mpi_install.sh"
        echo "========================================"
    else
        echo "UNINSTALL FALLITO"
        exit 1
    fi
}

main