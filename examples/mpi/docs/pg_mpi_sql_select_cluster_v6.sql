\x auto

-- Mostra anagrafiche raggruppate per cluster ordinate per plausibilità
\echo ''
\echo 'Anagrafiche raggruppate per identità (cluster):'
\echo ''
\echo 'NOTA: Per ogni identità sono mostrate multiple versioni ordinate per plausibilità.'
\echo 'La prima riga (MASTER) è quella più probabile, le altre sono alternative.'
\echo ''

SELECT 
    ca.nome_cluster as "Identità",
    CASE 
        WHEN cm.is_master THEN '█ MASTER'
        ELSE '░ alt.' || cm.ordinamento 
    END as "Tipo",
    ap.id as "ID",
    ap.nome as "Nome",
    COALESCE(ap.secondo_nome, '') as "Secondo Nome", 
    ap.data_nascita as "Nascita",
    ap.sesso as "Sesso",
    LEFT(ds.codice_fiscale_hash, 8) || '...' as "CF Hash",
    dcr.email as "Email"
FROM cluster_anagrafici ca
JOIN cluster_membri cm ON ca.id = cm.id_cluster  
JOIN anagrafiche_pazienti ap ON cm.id_anagrafica = ap.id
LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
LEFT JOIN dati_contatto_residenza dcr ON ap.id = dcr.id_paziente AND dcr.attivo = TRUE
WHERE ca.attivo = TRUE
ORDER BY ca.id, cm.is_master DESC, cm.ordinamento;