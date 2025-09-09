#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_recreate_database.sh -h <host> -u <user> -p <pass> -d <db_name> [-f]
# Distrugge e ricrea completamente il database
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

# Controlla se il container PostgreSQL è in esecuzione
check_container() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^${PG_CONTAINER}$"; then
        echo "ERRORE: Container PostgreSQL '${PG_CONTAINER}' non trovato"
        exit 1
    fi
}

# Testa la connessione al database PostgreSQL
test_connection() {
    if ! docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "postgres" -c "SELECT 1;" > /dev/null 2>&1; then
        echo "ERRORE: Impossibile connettersi a PostgreSQL"
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
    echo "⚠️ ATTENZIONE ESTREMA: Questo script DISTRUGGERÀ COMPLETAMENTE il database '$PG_DATABASE'!"
    echo "TUTTI I DATI NEL DATABASE VERRANNO PERSI DEFINITIVAMENTE!"
    echo ""
    echo "Vuoi continuare con la distruzione del database? [y/N]:"
    read -r confirmation
    case "$confirmation" in
        y|Y|yes|YES)
            echo "Confermata distruzione del database"
            ;;
        *)
            echo "Operazione annullata"
            exit 0
            ;;
    esac
}

# Drop del database
drop_database() {
    echo "Disconnessione di tutti gli utenti dal database $PG_DATABASE..."
    
    # Termina tutte le connessioni attive al database
    docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "postgres" -c "
        SELECT pg_terminate_backend(pg_stat_activity.pid)
        FROM pg_stat_activity
        WHERE pg_stat_activity.datname = '$PG_DATABASE'
          AND pid <> pg_backend_pid();
    " > /dev/null 2>&1 || true
    
    echo "Drop del database $PG_DATABASE..."
    if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "postgres" -c "DROP DATABASE IF EXISTS \"$PG_DATABASE\";"; then
        echo "✓ Database $PG_DATABASE eliminato con successo"
        return 0
    else
        echo "✗ Errore durante l'eliminazione del database"
        return 1
    fi
}

# Creazione del database
create_database() {
    echo "Creazione del nuovo database $PG_DATABASE..."
    if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "postgres" -c "
        CREATE DATABASE \"$PG_DATABASE\" 
        WITH 
            ENCODING = 'UTF8' 
            LC_COLLATE = 'en_US.utf8' 
            LC_CTYPE = 'en_US.utf8' 
            TEMPLATE = template0;
    "; then
        echo "✓ Database $PG_DATABASE creato con successo"
        return 0
    else
        echo "✗ Errore durante la creazione del database"
        return 1
    fi
}

# Verifica database
verify_database() {
    echo "Verifica nuovo database..."
    
    local db_exists=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "postgres" -c "
        SELECT COUNT(*) FROM pg_database WHERE datname = '$PG_DATABASE';
    " -t 2>/dev/null | tr -d ' ')
    
    if [[ "$db_exists" -eq "1" ]]; then
        echo "✓ Database $PG_DATABASE verificato correttamente"
        
        # Test connessione al nuovo database
        if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
            echo "✓ Connessione al nuovo database funzionante"
            return 0
        else
            echo "✗ Impossibile connettersi al nuovo database"
            return 1
        fi
    else
        echo "✗ Database non trovato dopo la creazione"
        return 1
    fi
}

main() {
    echo "========================================"
    echo "PostgreSQL Database Recreate"
    echo "========================================"
    
    # Verifiche preliminari
    check_container
    test_connection
    
    # Richiesta conferma
    request_confirmation
    
    echo "Avvio ricreazione database $PG_DATABASE..."
    
    # Drop e ricreazione database
    if drop_database && create_database; then
        echo ""
        verify_database
        echo ""
        echo "========================================"
        echo "RICREAZIONE DATABASE COMPLETATA!"
        echo "========================================"
        echo ""
        echo "Database: $PG_DATABASE (nuovo, vuoto)"
        echo "Container: $PG_CONTAINER"
        echo ""
        echo "Per installare il sistema anagrafico: ./pg_mpi_install.sh"
        echo "========================================"
    else
        echo ""
        echo "========================================"
        echo "RICREAZIONE DATABASE FALLITA!"
        echo "========================================"
        echo "Il database potrebbe essere in uno stato inconsistente"
        exit 1
    fi
}

main