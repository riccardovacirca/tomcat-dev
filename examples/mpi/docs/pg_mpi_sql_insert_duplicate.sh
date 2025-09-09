#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_sql_insert_duplicate.sh -h <host> -u <user> -p <pass> -d <db_name>
# Script per inserimento record di test che creano duplicati potenziali
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

# Header rimosso per output più pulito

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

# Esegui il file SQL dei duplicati (silenzioso)
if docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" < "$SCRIPT_DIR/pg_mpi_sql_insert_duplicate_v6.sql" > /dev/null 2>&1; then
    echo "✅ Inserimento completato"
else
    echo "❌ Errore durante l'inserimento"
    exit 1
fi

echo ""
echo "Pazienti di test inseriti:"
docker exec -i "$PG_CONTAINER" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
    SELECT 
        ap.id,
        ap.nome || COALESCE(' ' || ap.secondo_nome, '') as nome_completo,
        ap.data_nascita,
        ap.sesso,
        ap.citta_nascita,
        LEFT(ds.codice_fiscale_hash, 10) || '...' as cf_hash_short,
        dcr.email
    FROM anagrafiche_pazienti ap
    LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
    LEFT JOIN dati_contatto_residenza dcr ON ap.id = dcr.id_paziente AND dcr.attivo = TRUE
    WHERE ap.creato_da = 'test_user_duplicates'
    ORDER BY ap.data_creazione;
" 2>/dev/null || echo "Errore nel recupero dati pazienti"

# Fine script - solo tabella pazienti