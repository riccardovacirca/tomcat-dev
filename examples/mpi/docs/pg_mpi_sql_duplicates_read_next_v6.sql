-- ========================================
-- LETTURA PROSSIMO DUPLICATO - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- Query per recuperare prossimo duplicato da processare
-- ========================================

-- Formato output ottimizzato per parsing (silenzioso)
\set QUIET on
\pset format unaligned
\pset fieldsep '|'
\pset tuples_only on
\set QUIET off

-- ========================================
-- RECUPERA PROSSIMO DUPLICATO DA PROCESSARE
-- ========================================

SELECT 
    cd.id as duplicate_id,
    cd.id_paziente_primario,
    cd.id_paziente_candidato,
    cd.score_matching,
    cd.stato,
    cd.priorita,
    -- Dati paziente primario
    COALESCE(ap1.nome, '') as nome_a, 
    COALESCE(ap1.secondo_nome, '') as secondo_nome_a, 
    COALESCE(ap1.data_nascita::text, '') as data_nascita_a,
    COALESCE(ap1.sesso, '') as sesso_a, 
    COALESCE(ap1.citta_nascita, '') as luogo_nascita_a,
    COALESCE(SUBSTRING(ds1.codice_fiscale_hash, 1, 10), '') as cf_hash_a,
    COALESCE(dcr1.cellulare, '') as cellulare_a, 
    COALESCE(dcr1.telefono, '') as telefono_a, 
    COALESCE(dcr1.email, '') as email_a,
    -- Dati paziente candidato  
    COALESCE(ap2.nome, '') as nome_b, 
    COALESCE(ap2.secondo_nome, '') as secondo_nome_b, 
    COALESCE(ap2.data_nascita::text, '') as data_nascita_b,
    COALESCE(ap2.sesso, '') as sesso_b, 
    COALESCE(ap2.citta_nascita, '') as luogo_nascita_b,
    COALESCE(SUBSTRING(ds2.codice_fiscale_hash, 1, 10), '') as cf_hash_b,
    COALESCE(dcr2.cellulare, '') as cellulare_b, 
    COALESCE(dcr2.telefono, '') as telefono_b, 
    COALESCE(dcr2.email, '') as email_b
FROM candidati_duplicati cd
JOIN anagrafiche_pazienti ap1 ON cd.id_paziente_primario = ap1.id
JOIN anagrafiche_pazienti ap2 ON cd.id_paziente_candidato = ap2.id
LEFT JOIN dati_sensibili_pazienti ds1 ON ap1.id = ds1.id_paziente
LEFT JOIN dati_sensibili_pazienti ds2 ON ap2.id = ds2.id_paziente
LEFT JOIN dati_contatto_residenza dcr1 ON ap1.id = dcr1.id_paziente AND dcr1.attivo = TRUE
LEFT JOIN dati_contatto_residenza dcr2 ON ap2.id = dcr2.id_paziente AND dcr2.attivo = TRUE
WHERE cd.stato IN ('NUOVO', 'CONFERMATO')
ORDER BY 
    CASE cd.priorita WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 WHEN 'BASSA' THEN 3 END,
    cd.score_matching DESC,
    cd.data_creazione
LIMIT 1;