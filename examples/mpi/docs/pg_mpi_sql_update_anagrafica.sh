#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_sql_update_anagrafica.sh -h <host> -u <user> -p <pass> -d <db_name>
# Script di test per UPDATE anagrafica PostgreSQL
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

echo "========================================"
echo "PostgreSQL MPI - Test UPDATE Anagrafica"
echo "========================================"
echo "Container: $PG_CONTAINER"
echo "Database: $PG_DATABASE"
echo "========================================"
echo ""

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

# Verifica esistenza paziente di test
patient_exists=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
    SELECT COUNT(*) FROM anagrafiche_pazienti 
    WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID;
" -t 2>/dev/null | tr -d ' ')

if [[ "$patient_exists" -eq "0" ]]; then
    echo "⚠ WARNING: Paziente di test non trovato!"
    echo "Eseguire prima: ./pg_mpi_sql_insert_anagrafica.sh"
    echo ""
    echo "Il paziente deve avere UUID: f47ac10b-58cc-4372-a567-0e02b2c3d999"
    echo ""
    read -p "Continuare comunque? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operazione annullata"
        exit 0
    fi
fi

echo "🔄 Esecuzione UPDATE anagrafica..."
echo ""

# Esegui lo script SQL di update
if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" < "$SCRIPT_DIR/pg_mpi_sql_update_anagrafica_v6.sql"; then
    echo ""
    echo "✅ Script UPDATE anagrafica eseguito"
else
    echo ""
    echo "❌ Errore durante l'esecuzione dello script UPDATE"
    exit 1
fi

echo ""
echo "========================================"
echo "UPDATE ANAGRAFICA COMPLETATO"
echo ""
echo "📋 MODIFICHE APPLICATE:"
echo "- Nome: Mario → Mario Alessandro"
echo "- Secondo cognome: NULL → De"
echo "- Contatti: Cellulare, telefono, email aggiornati"
echo "- Indirizzo: Via Roma 123 → Via Roma 123, Interno 5A"
echo "- Documento: CI123456 → PS123456 (Passaporto)"
echo "- ID Esterno: EXT_MARIO_001 → EXT_MARIO_001_UPDATED"
echo ""
echo "💡 WORKFLOW COMPLETO:"
echo "1. INSERT: ./pg_mpi_sql_insert_anagrafica.sh"
echo "2. UPDATE: ./pg_mpi_sql_update_anagrafica.sh (questo script)"
echo "3. DELETE: ./pg_mpi_sql_delete_anagrafica.sh"
echo "========================================"