#!/bin/bash
set -e
# ==============================================================================
# pg_mpi_script_duplicates_details.sh - PLACEHOLDER
# Azione: Mostra dettagli score matching
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
echo "📊 DETTAGLI SCORE MATCHING"
echo "========================================="
echo "Duplicate ID: $DUPLICATE_ID"
echo ""

# Recupera dati dettagliati del duplicato
echo "Debug: Tentativo di recupero dati per ID $DUPLICATE_ID..."

duplicate_details=$(docker exec -i "$PG_CONTAINER" env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
    SELECT 
        cd.score_matching,
        cd.tipo_rilevamento,
        cd.data_creazione,
        COALESCE(cd.note_revisore, '') as note_revisore,
        COALESCE(am.nome, 'N/A') as algoritmo_nome,
        COALESCE(am.peso_nome, 0) as peso_nome,
        COALESCE(am.peso_cognome, 0) as peso_cognome, 
        COALESCE(am.peso_data_nascita, 0) as peso_data_nascita,
        COALESCE(am.peso_codice_fiscale, 0) as peso_codice_fiscale,
        COALESCE(am.peso_luogo_nascita, 0) as peso_luogo_nascita,
        COALESCE(am.soglia_duplicato_certo, 0) as soglia_duplicato_certo,
        COALESCE(am.soglia_duplicato_probabile, 0) as soglia_duplicato_probabile
    FROM candidati_duplicati cd
    LEFT JOIN algoritmi_matching am ON cd.id_algoritmo = am.id
    WHERE cd.id = $DUPLICATE_ID;
" -t 2>/dev/null)

echo "Debug: Query completata, risultato: ${#duplicate_details} caratteri"

if [[ -n "$duplicate_details" ]]; then
    echo "SCORE TOTALE E ALGORITMO:"
    echo "$duplicate_details" | while IFS='|' read -r score tipo data note_revisore algoritmo peso_nome peso_cognome peso_data peso_cf peso_luogo soglia_certo soglia_prob; do
        echo "Score finale: $(echo $score | tr -d ' ')%"
        echo "Tipo rilevamento: $(echo $tipo | tr -d ' ')"
        echo "Data rilevamento: $(echo $data | tr -d ' ')"
        echo "Algoritmo: $(echo $algoritmo | tr -d ' ')"
        echo ""
        echo "PESI ALGORITMO:"
        echo "- Nome: $(echo $peso_nome | tr -d ' ')"
        echo "- Cognome: $(echo $peso_cognome | tr -d ' ')"
        echo "- Data nascita: $(echo $peso_data | tr -d ' ')"
        echo "- Codice fiscale: $(echo $peso_cf | tr -d ' ')"
        echo "- Luogo nascita: $(echo $peso_luogo | tr -d ' ')"
        echo ""
        echo "SOGLIE:"
        echo "- Duplicato certo: $(echo $soglia_certo | tr -d ' ')%"
        echo "- Duplicato probabile: $(echo $soglia_prob | tr -d ' ')%"
        echo ""
        echo "NOTE REVISORE:"
        echo "$(echo $note_revisore | tr -d ' ')"
    done
else
    echo "❌ Impossibile recuperare dettagli per ID: $DUPLICATE_ID"
fi

echo ""
echo "❌ FUNZIONALITÀ PARZIALMENTE IMPLEMENTATA"
echo ""
echo "Dettagli aggiuntivi non disponibili:"
echo "- Breakdown score per singolo campo"
echo "- Confronto valori specifici"
echo "- Storico modifiche algoritmo"
echo "- Analisi false positive/negative"