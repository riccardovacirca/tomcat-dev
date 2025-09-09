\x auto

\echo ''
\echo '========================================'
\echo 'ANAGRAFICHE PAZIENTI'
\echo '========================================'

SELECT id, uid, nome, secondo_nome, data_nascita, sesso, citta_nascita,
    provincia_nascita, nazione_nascita, consenso_privacy, data_consenso_privacy,
    versione, stato_merge, attivo, data_creazione, creato_da, data_modifica
FROM anagrafiche_pazienti 
WHERE attivo = true 
ORDER BY data_creazione DESC
LIMIT 10;

\echo ''
\echo '========================================'
\echo 'DATI SENSIBILI (HASH)'
\echo '========================================'

SELECT ds.id_paziente, a.nome, a.secondo_nome, ds.codice_fiscale_hash,
    ds.cognome_hash, ds.secondo_cognome_hash, ds.data_creazione,
    ds.data_modifica
FROM dati_sensibili_pazienti ds
JOIN anagrafiche_pazienti a ON a.id = ds.id_paziente
WHERE a.attivo = true
ORDER BY ds.data_creazione DESC
LIMIT 10;

\echo ''
\echo '========================================'
\echo 'DATI CONTATTO/RESIDENZA'
\echo '========================================'

SELECT dcr.id_paziente, a.nome, a.secondo_nome, dcr.cellulare, dcr.telefono,
    dcr.email, dcr.indirizzo_residenza, dcr.citta_residenza,
    dcr.provincia_residenza, dcr.cap_residenza, dcr.numero_documento,
    dcr.versione, dcr.attivo, dcr.data_creazione, dcr.creato_da
FROM dati_contatto_residenza dcr
JOIN anagrafiche_pazienti a ON a.id = dcr.id_paziente
WHERE dcr.attivo = true
ORDER BY dcr.data_creazione DESC
LIMIT 10;

\echo ''
\echo '========================================'
\echo 'LOG AUDIT'
\echo '========================================'

SELECT la.id, la.nome_tabella, la.id_record, la.operazione, la.id_utente,
    la.id_sessione, la.indirizzo_ip, la.user_agent, la.data_creazione,
    LENGTH(la.valori_nuovi) as lunghezza_dati
FROM log_audit_anagrafico la
ORDER BY la.data_creazione DESC
LIMIT 20;

\echo ''
\echo '========================================'
\echo 'STATISTICHE SISTEMA'
\echo '========================================'

SELECT 
    'Pazienti Attivi' as categoria,
    COUNT(*) as totale
FROM anagrafiche_pazienti 
WHERE attivo = true AND stato_merge = 'ATTIVO'

UNION ALL

SELECT 
    'Dati Sensibili' as categoria,
    COUNT(*) as totale
FROM dati_sensibili_pazienti

UNION ALL

SELECT 
    'Contatti Attivi' as categoria,
    COUNT(*) as totale
FROM dati_contatto_residenza
WHERE attivo = true

UNION ALL

SELECT 
    'Operazioni Audit' as categoria,
    COUNT(*) as totale
FROM log_audit_anagrafico

ORDER BY categoria;

\echo ''
\echo '========================================'
\echo 'ULTIMO PAZIENTE INSERITO (COMPLETO)'
\echo '========================================'

WITH ultimo_paziente AS (
    SELECT id, uid, nome, secondo_nome 
    FROM anagrafiche_pazienti 
    WHERE attivo = true 
    ORDER BY data_creazione DESC 
    LIMIT 1
)
SELECT 
    'ANAGRAFICA' as tipo_dato,
    JSON_BUILD_OBJECT(
        'id', a.id,
        'uid', a.uid,
        'nome', a.nome,
        'secondo_nome', a.secondo_nome,
        'data_nascita', a.data_nascita,
        'sesso', a.sesso,
        'consenso_privacy', a.consenso_privacy,
        'data_creazione', a.data_creazione,
        'creato_da', a.creato_da
    ) as dati
FROM anagrafiche_pazienti a
JOIN ultimo_paziente up ON up.id = a.id

UNION ALL

SELECT 
    'CONTATTI' as tipo_dato,
    JSON_BUILD_OBJECT(
        'cellulare', dcr.cellulare,
        'telefono', dcr.telefono,
        'email', dcr.email,
        'indirizzo', dcr.indirizzo_residenza,
        'citta', dcr.citta_residenza,
        'provincia', dcr.provincia_residenza,
        'cap', dcr.cap_residenza
    ) as dati
FROM dati_contatto_residenza dcr
JOIN ultimo_paziente up ON up.id = dcr.id_paziente
WHERE dcr.attivo = true

UNION ALL

SELECT 
    'AUDIT' as tipo_dato,
    JSON_BUILD_OBJECT(
        'operazione', la.operazione,
        'utente', la.id_utente,
        'sessione', la.id_sessione,
        'ip', la.indirizzo_ip,
        'timestamp', la.data_creazione
    ) as dati
FROM log_audit_anagrafico la
JOIN ultimo_paziente up ON up.id = la.id_record
WHERE la.nome_tabella = 'anagrafiche_pazienti'
ORDER BY tipo_dato;