#!/bin/bash
set -e
# ==============================================================================
# pg_mpi_script_duplicates_reject.sh - PLACEHOLDER
# Azione: Respingi duplicato - Non sono la stessa persona
# ==============================================================================

PG_CONTAINER=""
PG_USERNAME=""
PG_PASSWORD=""
PG_DATABASE=""
DUPLICATE_ID=""

while getopts "h:u:p:d:i:" opt; do
  case $opt in
    h) PG_CONTAINER="$OPTARG" ;;
    u) PG_USERNAME="$OPTARG" ;;
    p) PG_PASSWORD="$OPTARG" ;;
    d) PG_DATABASE="$OPTARG" ;;
    i) DUPLICATE_ID="$OPTARG" ;;
    \?) echo "Opzione non valida: -$OPTARG" >&2; exit 1 ;;
  esac
done

echo "========================================="
echo "❌ RESPINGI DUPLICATO - PLACEHOLDER"
echo "========================================="
echo "Duplicate ID: $DUPLICATE_ID"
echo ""
echo "❌ FUNZIONALITÀ NON ANCORA IMPLEMENTATA"
echo ""
echo "Questa azione dovrebbe:"
echo "1. Aggiornare stato candidato_duplicati a 'RESPINTO'"
echo "2. Registrare motivo di respingimento"
echo "3. Aggiornare log audit"
echo "4. Opzionalmente aggiungere a blacklist temporanea"
echo ""
echo "SIMULAZIONE: Duplicato marcato come RESPINTO"

# Placeholder: aggiorna solo lo stato
docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
    UPDATE candidati_duplicati 
    SET stato = 'RESPINTO',
        data_modifica = NOW(),
        modificato_da = 'dashboard_user',
        note_revisione = 'Respinto da operatore - Non sono la stessa persona'
    WHERE id = $DUPLICATE_ID;
" > /dev/null 2>&1

echo "✅ Azione simulata completata"