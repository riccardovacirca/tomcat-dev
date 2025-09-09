#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_sql_duplicates_detect.sh -h <host> -u <user> -p <pass> -d <db_name> [-s batch_size]
# Wrapper per esecuzione SQL rilevamento duplicati
# ==============================================================================

PG_CONTAINER=""
PG_USERNAME=""
PG_PASSWORD=""
PG_DATABASE=""
BATCH_SIZE=20

while getopts "h:u:p:d:s:" opt; do
  case $opt in
    h) PG_CONTAINER="$OPTARG" ;;
    u) PG_USERNAME="$OPTARG" ;;
    p) PG_PASSWORD="$OPTARG" ;;
    d) PG_DATABASE="$OPTARG" ;;
    s) BATCH_SIZE="$OPTARG" ;;
    \?) echo "Opzione non valida: -$OPTARG" >&2; exit 1 ;;
  esac
done

# Verifica parametri obbligatori
if [[ -z "$PG_CONTAINER" || -z "$PG_USERNAME" || -z "$PG_PASSWORD" || -z "$PG_DATABASE" ]]; then
    echo "Uso: $0 -h <container> -u <user> -p <password> -d <database> [-s batch_size]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/pg_mpi_sql_duplicates_detect_v6.sql"

if [[ ! -f "$SQL_FILE" ]]; then
    echo "ERRORE: File SQL non trovato: $SQL_FILE"
    exit 1
fi

# Controlla se il container è attivo
if ! docker ps --format "table {{.Names}}" | grep -q "^${PG_CONTAINER}$"; then
    echo "ERRORE: Container PostgreSQL '$PG_CONTAINER' non trovato"
    exit 1
fi

# Controlla connessione database
if ! docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "ERRORE: Impossibile connettersi al database PostgreSQL"
    exit 1
fi

# Header rimosso per output più pulito

# Esegui script SQL con parametro batch_size
docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" \
    -v batch_size="$BATCH_SIZE" \
    -f /dev/stdin < "$SQL_FILE"

if [[ $? -eq 0 ]]; then
    echo ""
    echo "✓ Elaborazione completata con successo"
else
    echo ""
    echo "✗ ERRORE durante elaborazione"
    exit 1
fi