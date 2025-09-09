#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_install_sp_restore.sh -h <host> -u <user> -p <pass> -d <db_name>
# Script per installazione/aggiornamento Stored Procedures RESTORE PostgreSQL
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
SQL_FILE="pg_mpi_install_sp_restore_v6.sql"

echo "========================================"
echo "PostgreSQL MPI - Installazione SP RESTORE"
echo "========================================"
echo "Container: $PG_CONTAINER"
echo "Database: $PG_DATABASE"
echo "File: $SQL_FILE"
echo "========================================"
echo ""

# Controlla se il container è attivo
if ! docker ps --format "table {{.Names}}" | grep -q "^${PG_CONTAINER}$"; then
    echo "ERRORE: Container PostgreSQL '$PG_CONTAINER' non trovato"
    exit 1
fi

# Controlla se il file SQL esiste
if [[ ! -f "$SCRIPT_DIR/$SQL_FILE" ]]; then
    echo "ERRORE: File SQL non trovato: $SCRIPT_DIR/$SQL_FILE"
    exit 1
fi

# Controlla connessione database
if ! docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "ERRORE: Impossibile connettersi al database PostgreSQL"
    exit 1
fi

echo "🔄 Installazione stored procedures RESTORE..."
echo ""

# Esegui il file SQL
if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" < "$SCRIPT_DIR/$SQL_FILE"; then
    echo ""
    echo "✅ Stored procedures RESTORE installate con successo"
else
    echo ""
    echo "❌ Errore durante l'installazione delle stored procedures RESTORE"
    exit 1
fi

echo ""
echo "🔍 Verifica installazione..."

# Verifica le stored procedures installate
procedures_check=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
    SELECT COUNT(*) FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name IN (
        'sp_restore_anagrafica_transazionale',
        'sp_check_restore_eligibility'
    );
" -t 2>/dev/null | tr -d ' ')

if [[ "$procedures_check" -eq "2" ]]; then
    echo "✅ Tutte le stored procedures RESTORE verificate (2/2)"
else
    echo "⚠ Alcune stored procedures potrebbero non essere installate correttamente ($procedures_check/2)"
fi

echo ""
echo "========================================"
echo "INSTALLAZIONE SP RESTORE COMPLETATA"
echo ""
echo "📋 STORED PROCEDURES INSTALLATE:"
echo "1. sp_restore_anagrafica_transazionale"
echo "   └─ Ripristino completo anagrafica cancellata"
echo "   └─ Audit automatico dell'operazione"
echo "   └─ Gestione transazionale con rollback"
echo ""
echo "2. sp_check_restore_eligibility"
echo "   └─ Verifica eligibilità paziente per ripristino"
echo "   └─ Controlli stato e validazioni preliminari"
echo "   └─ Informazioni dettagliate paziente"
echo ""
echo "🧪 TEST DISPONIBILI:"
echo "./pg_mpi_sql_restore_anagrafica.sh -h $PG_CONTAINER -u $PG_USERNAME -p *** -d $PG_DATABASE"
echo ""
echo "📖 ESEMPI UTILIZZO:"
echo "-- Verifica eligibilità"
echo "SELECT * FROM sp_check_restore_eligibility(123);"
echo ""
echo "-- Ripristino paziente"
echo "SELECT * FROM sp_restore_anagrafica_transazionale(123, 'admin', 'session_id', '127.0.0.1'::INET, 'App/1.0');"
echo "========================================"