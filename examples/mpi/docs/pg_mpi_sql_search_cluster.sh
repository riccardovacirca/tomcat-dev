#!/bin/bash
set -e
# ==============================================================================
# ./pg_mpi_sql_search_cluster.sh -h <host> -u <user> -p <pass> -d <db_name>
# Script interattivo per ricerca anagrafiche nei cluster
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

# Verifica esistenza container PostgreSQL
if ! docker ps --format "table {{.Names}}" | grep -q "^${PG_CONTAINER}$"; then
  echo "ERRORE: Container PostgreSQL '${PG_CONTAINER}' non trovato"
  exit 1
fi

echo "Ricerca anagrafica nei cluster"
echo "Puoi cercare per: UUID, nome, cognome, codice fiscale"
echo ""
read -p "query> " SEARCH_QUERY

# Pulisci la query (rimuovi spazi extra e converti in minuscolo per confronto)
SEARCH_QUERY=$(echo "$SEARCH_QUERY" | xargs)

if [[ -z "$SEARCH_QUERY" ]]; then
    echo "Query vuota. Operazione annullata."
    exit 0
fi

echo ""
echo "Ricerca per: '$SEARCH_QUERY'"
echo ""

# Esegui ricerca cluster
docker exec -i "$PG_CONTAINER" env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USERNAME" -d "$PG_DATABASE" << EOF

-- Ricerca nei cluster attivi
WITH ricerca_cluster AS (
    SELECT DISTINCT ca.id as cluster_id, ca.nome_cluster, ca.cluster_uuid
    FROM cluster_anagrafici ca
    JOIN cluster_membri cm ON ca.id = cm.id_cluster  
    JOIN anagrafiche_pazienti ap ON cm.id_anagrafica = ap.id
    LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
    WHERE ca.attivo = TRUE
      AND (
        -- Ricerca per UUID (esatto)
        UPPER(ca.cluster_uuid::text) = UPPER('$SEARCH_QUERY')
        OR UPPER(ap.uid::text) = UPPER('$SEARCH_QUERY')
        -- Ricerca per nome (parziale, case-insensitive)
        OR UPPER(ap.nome) LIKE UPPER('%$SEARCH_QUERY%')
        OR UPPER(COALESCE(ap.secondo_nome, '')) LIKE UPPER('%$SEARCH_QUERY%')
        -- Ricerca per cognome tramite hash (confronto esatto dell'hash)
        OR ds.cognome_hash = encode(sha256(UPPER('$SEARCH_QUERY')::bytea), 'hex')
        -- Ricerca per codice fiscale tramite hash (confronto esatto dell'hash)  
        OR ds.codice_fiscale_hash = encode(sha256(UPPER('$SEARCH_QUERY')::bytea), 'hex')
      )
)
SELECT 
    rc.nome_cluster as identita,
    CASE 
        WHEN cm.is_master THEN 'MASTER'
        ELSE 'alt.' || cm.ordinamento 
    END as tipo,
    ap.id,
    ap.nome,
    COALESCE(ap.secondo_nome, '') as secondo_nome, 
    ap.data_nascita,
    ap.sesso,
    LEFT(ds.codice_fiscale_hash, 8) || '...' as cf_hash,
    dcr.email
FROM ricerca_cluster rc
JOIN cluster_anagrafici ca ON rc.cluster_id = ca.id
JOIN cluster_membri cm ON ca.id = cm.id_cluster  
JOIN anagrafiche_pazienti ap ON cm.id_anagrafica = ap.id
LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
LEFT JOIN dati_contatto_residenza dcr ON ap.id = dcr.id_paziente AND dcr.attivo = TRUE
ORDER BY rc.cluster_id, cm.is_master DESC, cm.ordinamento;
EOF

# Controlla se la ricerca ha restituito risultati
RESULT_COUNT=$(docker exec -i "$PG_CONTAINER" env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -t << EOF | xargs
WITH ricerca_cluster AS (
    SELECT DISTINCT ca.id as cluster_id
    FROM cluster_anagrafici ca
    JOIN cluster_membri cm ON ca.id = cm.id_cluster  
    JOIN anagrafiche_pazienti ap ON cm.id_anagrafica = ap.id
    LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
    WHERE ca.attivo = TRUE
      AND (
        UPPER(ca.cluster_uuid::text) = UPPER('$SEARCH_QUERY')
        OR UPPER(ap.uid::text) = UPPER('$SEARCH_QUERY')
        OR UPPER(ap.nome) LIKE UPPER('%$SEARCH_QUERY%')
        OR UPPER(COALESCE(ap.secondo_nome, '')) LIKE UPPER('%$SEARCH_QUERY%')
        OR ds.cognome_hash = encode(sha256(UPPER('$SEARCH_QUERY')::bytea), 'hex')
        OR ds.codice_fiscale_hash = encode(sha256(UPPER('$SEARCH_QUERY')::bytea), 'hex')
      )
)
SELECT COUNT(*) FROM ricerca_cluster;
EOF
)

echo ""
if [[ "$RESULT_COUNT" -eq 0 ]]; then
    echo "Nessun cluster trovato per la query: '$SEARCH_QUERY'"
    echo ""
    echo "Suggerimenti:"
    echo "- Prova con parte del nome (es. 'Mario')"
    echo "- Verifica che esistano cluster attivi"
    echo "- Per cognome/CF usa il valore esatto"
else
    echo "Trovati $RESULT_COUNT cluster corrispondenti alla ricerca"
fi