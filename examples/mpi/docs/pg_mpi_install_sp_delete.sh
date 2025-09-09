#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_install_sp_delete.sh -h <host> -u <user> -p <pass> -d <db_name>
# Installazione singola stored procedure DELETE (soft delete)
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
SQL_FILE="pg_mpi_install_sp_delete_v6.sql"

echo "========================================"
echo "PostgreSQL MPI - Install SP DELETE"
echo "========================================"
echo "Container: $PG_CONTAINER"
echo "Database: $PG_DATABASE"
echo "File: $SQL_FILE"
echo "========================================"

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

echo "🔄 Installazione stored procedures DELETE..."

# Esegui il file SQL
if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" < "$SCRIPT_DIR/$SQL_FILE"; then
    echo ""
    echo "✅ Stored procedures DELETE installate con successo"
else
    echo ""
    echo "❌ Errore durante l'installazione delle stored procedures DELETE"
    exit 1
fi

# Verifica installazione
echo ""
echo "📋 Verifica installazione..."
procedure_count=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
    SELECT COUNT(*) FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name IN ('sp_delete_anagrafica_transazionale', 'sp_restore_anagrafica_transazionale');
" -t 2>/dev/null | tr -d ' ')

if [[ "$procedure_count" -eq "2" ]]; then
    echo "✅ Stored procedures DELETE e RESTORE verificate"
else
    echo "⚠ Problema con l'installazione delle stored procedures ($procedure_count/2)"
fi

echo ""
echo "========================================"
echo "INSTALLAZIONE SP DELETE COMPLETATA"
echo "========================================"