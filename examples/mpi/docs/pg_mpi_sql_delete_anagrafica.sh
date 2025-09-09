#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_sql_delete_anagrafica.sh -h <host> -u <user> -p <pass> -d <db_name>
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
SQL_FILE="pg_mpi_sql_delete_anagrafica_v6.sql"

# ========================================
# ESECUZIONE
# ========================================

echo "========================================"
echo "PostgreSQL Soft Delete Anagrafica"  
echo "Sistema MPI"
echo "========================================"

# Controlla se il container è attivo
if ! docker ps --format "table {{.Names}}" | grep -q "^${PG_CONTAINER}$"; then
    echo "ERRORE: Container PostgreSQL '${PG_CONTAINER}' non trovato"
    exit 1
fi

# Controlla se il file SQL esiste
if [[ ! -f "${SCRIPT_DIR}/${SQL_FILE}" ]]; then
    echo "ERRORE: File SQL non trovato: ${SQL_FILE}"
    exit 1
fi

echo "Esecuzione soft delete anagrafica..."
echo

# Esegui il file SQL
docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" < "${SCRIPT_DIR}/${SQL_FILE}"

echo
echo "========================================"
echo "Soft delete completato"
echo "========================================"