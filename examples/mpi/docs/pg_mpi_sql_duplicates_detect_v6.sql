-- ========================================
-- RILEVAMENTO DUPLICATI BATCH - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- Elaborazione batch coda scan duplicati
-- ========================================

-- Formato output migliorato
\x auto

-- Esegui elaborazione batch duplicati (output nascosto)
\set QUIET on
SELECT * FROM sp_process_duplicate_scan_batch(:batch_size);
\set QUIET off

-- Mostra solo la tabella dei duplicati rilevati
\echo ''
\echo 'Top 5 duplicati per score (ultimi rilevati):'

SELECT 
    cd.id,
    cd.id_paziente_primario,
    cd.id_paziente_candidato,
    cd.score_matching,
    cd.stato,
    cd.priorita,
    ap1.nome || ' ' || COALESCE(ap1.secondo_nome, '') as paziente_a,
    ap2.nome || ' ' || COALESCE(ap2.secondo_nome, '') as paziente_b
FROM candidati_duplicati cd
JOIN anagrafiche_pazienti ap1 ON cd.id_paziente_primario = ap1.id
JOIN anagrafiche_pazienti ap2 ON cd.id_paziente_candidato = ap2.id
WHERE cd.data_creazione >= NOW() - INTERVAL '10 minutes'
ORDER BY cd.score_matching DESC, cd.data_creazione DESC
LIMIT 5;

-- Fine script