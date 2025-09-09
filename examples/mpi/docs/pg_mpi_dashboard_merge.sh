#!/bin/bash
set -e
# ==============================================================================
# pg_mpi_dashboard_merge.sh - CREAZIONE CLUSTER DA DUPLICATI
# Azione: Conferma duplicato e crea cluster anagrafici
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

# Verifica parametri obbligatori
if [[ -z "$PG_CONTAINER" || -z "$PG_USERNAME" || -z "$PG_PASSWORD" || -z "$PG_DATABASE" || -z "$DUPLICATE_ID" ]]; then
    echo "❌ ERRORE: Parametri mancanti"
    echo "Uso: $0 -h <container> -u <user> -p <password> -d <database> -i <duplicate_id>"
    exit 1
fi

echo "========================================="
echo "🔗 CREAZIONE CLUSTER DA DUPLICATI"
echo "========================================="
echo "Duplicate ID: $DUPLICATE_ID"
echo "Container: $PG_CONTAINER"
echo "Database: $PG_DATABASE"
echo ""

# Verifica che il candidato esista e sia confermabile
echo "📋 Verifica candidato duplicato..."
CANDIDATE_CHECK=$(docker exec -i "$PG_CONTAINER" env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -t -c "
    SELECT 
        cd.stato,
        ap1.nome || ' ' || COALESCE(ap1.secondo_nome, '') as paziente_a,
        ap2.nome || ' ' || COALESCE(ap2.secondo_nome, '') as paziente_b,
        cd.score_matching
    FROM candidati_duplicati cd
    JOIN anagrafiche_pazienti ap1 ON cd.id_paziente_primario = ap1.id
    JOIN anagrafiche_pazienti ap2 ON cd.id_paziente_candidato = ap2.id
    WHERE cd.id = $DUPLICATE_ID;
" 2>/dev/null)

if [[ -z "$CANDIDATE_CHECK" ]]; then
    echo "❌ ERRORE: Candidato duplicato ID $DUPLICATE_ID non trovato"
    exit 1
fi

echo "✅ Candidato trovato:"
echo "$CANDIDATE_CHECK" | while IFS='|' read -r stato paziente_a paziente_b score; do
    echo "   • Stato: $(echo $stato | tr -d ' ')"
    echo "   • Paziente A: $(echo $paziente_a | tr -d ' ')"
    echo "   • Paziente B: $(echo $paziente_b | tr -d ' ')"
    echo "   • Score: $(echo $score | tr -d ' ')%"
done

echo ""

# Prima conferma il candidato se non è già confermato
echo "🔄 Conferma candidato duplicato..."
docker exec -i "$PG_CONTAINER" env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -c "
    UPDATE candidati_duplicati 
    SET stato = 'CONFERMATO',
        note_revisore = CONCAT(
            COALESCE(note_revisore, ''), 
            ' - Confermato da dashboard il ', NOW()::DATE
        ),
        data_modifica = NOW()
    WHERE id = $DUPLICATE_ID
      AND stato IN ('NUOVO', 'IN_REVIEW');
" > /dev/null 2>&1

echo "✅ Candidato confermato"
echo ""

# Ora crea il cluster
echo "🏗️  Creazione cluster..."
CLUSTER_RESULT=$(docker exec -i "$PG_CONTAINER" env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USERNAME" -d "$PG_DATABASE" -t -c "
    SELECT 
        cluster_id,
        cluster_uuid,
        id_master,
        membri_aggiunti,
        result_code,
        result_message
    FROM sp_crea_cluster_da_candidato($DUPLICATE_ID, 'dashboard_user');
")

if [[ -z "$CLUSTER_RESULT" ]]; then
    echo "❌ ERRORE: Impossibile creare cluster"
    exit 1
fi

# Parse risultato
echo "$CLUSTER_RESULT" | while IFS='|' read -r cluster_id cluster_uuid id_master membri_aggiunti result_code result_message; do
    cluster_id=$(echo $cluster_id | tr -d ' ')
    result_code=$(echo $result_code | tr -d ' ')
    result_message=$(echo $result_message | tr -d ' ')
    
    if [[ "$result_code" == "0" ]]; then
        echo "✅ CLUSTER CREATO CON SUCCESSO!"
        echo "   • Cluster ID: $cluster_id"
        echo "   • UUID: $(echo $cluster_uuid | tr -d ' ')"
        echo "   • Master ID: $(echo $id_master | tr -d ' ')"
        echo "   • Membri: $(echo $membri_aggiunti | tr -d ' ')"
        echo ""
        echo "📊 Visualizza cluster creato:"
        echo "./pg_mpi_sql_select_cluster.sh -h $PG_CONTAINER -u $PG_USERNAME -p $PG_PASSWORD -d $PG_DATABASE"
    else
        echo "❌ ERRORE CREAZIONE CLUSTER:"
        echo "   • Codice: $result_code"
        echo "   • Messaggio: $result_message"
        exit 1
    fi
done

echo ""
echo "========================================="
echo "🎉 OPERAZIONE COMPLETATA!"
echo "Il duplicato è stato trasformato in cluster."
echo "========================================="