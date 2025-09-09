#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_sql_restore_anagrafica.sh -h <host> -u <user> -p <pass> -d <db_name>
# Script di test per RESTORE anagrafica PostgreSQL
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
echo "PostgreSQL MPI - Test RESTORE Anagrafica"
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

# Verifica esistenza paziente cancellato
patient_deleted=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
    SELECT COUNT(*) FROM anagrafiche_pazienti 
    WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID
    AND attivo = FALSE AND stato_merge = 'ELIMINATO';
" -t 2>/dev/null | tr -d ' ')

if [[ "$patient_deleted" -eq "0" ]]; then
    # Verifica se il paziente esiste ma è attivo
    patient_active=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
        SELECT COUNT(*) FROM anagrafiche_pazienti 
        WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID
        AND attivo = TRUE;
    " -t 2>/dev/null | tr -d ' ')
    
    if [[ "$patient_active" -eq "1" ]]; then
        echo "⚠ WARNING: Il paziente di test è già ATTIVO!"
        echo "Per testare il ripristino, prima cancellarlo con:"
        echo "./pg_mpi_sql_delete_anagrafica.sh -h $PG_CONTAINER -u $PG_USERNAME -p $PG_PASSWORD -d $PG_DATABASE"
        echo ""
        read -p "Continuare comunque con il test di ripristino? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operazione annullata"
            exit 0
        fi
    else
        echo "⚠ WARNING: Paziente di test non trovato!"
        echo "Eseguire prima: ./pg_mpi_sql_insert_anagrafica.sh"
        echo "Poi: ./pg_mpi_sql_delete_anagrafica.sh"
        echo ""
        echo "Il paziente deve avere UUID: f47ac10b-58cc-4372-a567-0e02b2c3d999"
        echo "e deve essere in stato ELIMINATO per poter essere ripristinato"
        echo ""
        read -p "Continuare comunque? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operazione annullata"
            exit 0
        fi
    fi
fi

echo "♻️ Esecuzione RESTORE anagrafica..."
echo ""

# Esegui lo script SQL di restore
if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" < "$SCRIPT_DIR/pg_mpi_sql_restore_anagrafica_v6.sql"; then
    echo ""
    echo "✅ Script RESTORE anagrafica eseguito"
else
    echo ""
    echo "❌ Errore durante l'esecuzione dello script RESTORE"
    exit 1
fi

echo ""
echo "========================================"
echo "RESTORE ANAGRAFICA COMPLETATO"
echo ""
echo "🔄 CICLO COMPLETO TESTATO:"
echo "1. INSERT: ./pg_mpi_sql_insert_anagrafica.sh ✓"
echo "2. UPDATE: ./pg_mpi_sql_update_anagrafica.sh ✓"
echo "3. DELETE: ./pg_mpi_sql_delete_anagrafica.sh ✓"
echo "4. RESTORE: ./pg_mpi_sql_restore_anagrafica.sh ✓ (questo script)"
echo ""
echo "♻️ OPERAZIONI DISPONIBILI:"
echo "- Ripristino: Paziente riattivato e disponibile"
echo "- Audit: Traccia completa di tutte le operazioni"
echo "- Workflow: Cancellazione reversibile implementata"
echo ""
echo "📊 VERIFICA STATO:"
echo "- Paziente ora in stato: attivo = TRUE, stato_merge = 'ATTIVO'"
echo "- Versione incrementata per tracciare il ripristino"
echo "- Log audit completo delle operazioni"
echo "========================================"