-- ========================================
-- SIMPLE RESTORE ANAGRAFICA - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- Test semplice ripristino anagrafica paziente cancellata
-- ========================================

-- ⚠️  NOTA PER PRODUZIONE:
-- Questo script usa l'UUID del paziente cancellato con UUID fisso di test.
-- In produzione recuperare l'ID tramite:
-- 1. Parametro dall'applicazione
-- 2. Query di ricerca per nome/CF/altri campi univoci
-- 3. Dashboard di gestione pazienti cancellati
-- 
-- Il test ripristina il paziente Mario precedentemente cancellato

-- Formato output migliorato
\x auto

-- ========================================
-- RESTORE ANAGRAFICA PAZIENTE
-- ========================================

\echo ''
\echo '========================================'
\echo 'RESTORE ANAGRAFICA PAZIENTE'
\echo 'Sistema MPI - PostgreSQL'
\echo '========================================'
\echo ''

-- Test ripristino di un paziente precedentemente cancellato
SELECT 
    rows_affected,
    result_code,
    result_message,
    CASE 
        WHEN result_code = 0 THEN '✓ SUCCESS - Paziente ripristinato correttamente. Ora è nuovamente attivo nel sistema.'
        WHEN result_code = 4404 THEN '✗ ERROR - Paziente non trovato tra quelli cancellati'
        WHEN result_code = 4001 THEN '✗ ERROR - ID paziente non valido'
        ELSE '✗ ERROR'
    END as status
FROM sp_restore_anagrafica_transazionale(
    (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID),  -- ID paziente Mario di test
    'test_admin',                          -- Ripristinato da
    'test_session_restore',                -- ID sessione
    '127.0.0.1'::INET,                    -- Indirizzo IP
    'TestScript/1.0'                       -- User agent
);

-- ========================================
-- VERIFICA STATO DOPO RIPRISTINO
-- ========================================

\echo ''
\echo 'Stato paziente dopo ripristino:'

SELECT 
    id,
    uid,
    nome,
    secondo_nome,
    attivo,
    stato_merge,
    versione,
    data_modifica as ultima_modifica
FROM anagrafiche_pazienti 
WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID
ORDER BY id DESC
LIMIT 1;

-- ========================================
-- DATI CONTATTO DOPO RIPRISTINO
-- ========================================

\echo ''
\echo 'Dati contatto dopo ripristino:'

SELECT 
    dcr.id_paziente,
    dcr.cellulare,
    dcr.telefono,
    dcr.email,
    dcr.attivo,
    dcr.versione,
    dcr.data_modifica
FROM dati_contatto_residenza dcr
WHERE dcr.id_paziente = (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID)
ORDER BY dcr.id_paziente DESC
LIMIT 1;

-- ========================================
-- ASSOCIAZIONI DOPO RIPRISTINO
-- ========================================

\echo ''
\echo 'Associazioni paziente-dominio dopo ripristino:'

SELECT 
    apd.id_paziente,
    apd.id_dominio,
    apd.id_esterno,
    apd.stato,
    apd.data_modifica as ultima_modifica
FROM associazioni_paziente_dominio apd
WHERE apd.id_paziente = (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID)
ORDER BY apd.id_paziente DESC
LIMIT 5;

-- ========================================
-- LOG AUDIT DELL'OPERAZIONE
-- ========================================

\echo ''
\echo 'Log audit ripristino:'

SELECT 
    la.id,
    la.nome_tabella,
    la.id_record,
    la.operazione,
    la.id_utente,
    la.id_sessione,
    la.indirizzo_ip,
    la.data_creazione
FROM log_audit_anagrafico la
WHERE la.id_record = (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID)
  AND la.operazione = 'RESTORE'
ORDER BY la.data_creazione DESC
LIMIT 1;

-- ========================================
-- LISTA PAZIENTI ATTIVI (VERIFICA)
-- ========================================

\echo ''
\echo 'Lista pazienti attivi (ultimi 10):' 

SELECT 
    id,
    uid,
    nome,
    secondo_nome,
    data_modifica as ultima_modifica
FROM anagrafiche_pazienti 
WHERE attivo = TRUE AND stato_merge = 'ATTIVO'
ORDER BY data_modifica DESC
LIMIT 10;

-- ========================================
-- STORICO AUDIT COMPLETO DEL PAZIENTE
-- ========================================

\echo ''
\echo 'Storico completo operazioni paziente:'

SELECT 
    la.id,
    la.operazione,
    la.id_utente,
    la.data_creazione,
    CASE la.operazione::text
        WHEN 'INSERT' THEN '📝 Creazione'
        WHEN 'UPDATE' THEN '✏️ Modifica'
        WHEN 'DELETE' THEN '🗑️ Cancellazione'
        WHEN 'RESTORE' THEN '♻️ Ripristino'
        WHEN 'MERGE' THEN '🔄 Merge'
        ELSE la.operazione::text
    END as descrizione_operazione
FROM log_audit_anagrafico la
WHERE la.id_record = (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID)
ORDER BY la.data_creazione DESC
LIMIT 5;

-- ========================================
-- ESEMPIO CANCELLAZIONE SUCCESSIVA (COMMENTATO)
-- ========================================

\echo ''
\echo 'Per cancellare nuovamente il paziente, eseguire:'
\echo 'SELECT * FROM sp_delete_anagrafica_transazionale((SELECT id FROM anagrafiche_pazienti WHERE uid = ''f47ac10b-58cc-4372-a567-0e02b2c3d999''::UUID), ''admin_user'', ''Test cancellazione'', ''session_delete'', ''127.0.0.1''::INET, ''TestScript/1.0'');'

-- Decommentare per testare una nuova cancellazione:
/*
SELECT 
    rows_affected,
    result_code,
    result_message,
    CASE 
        WHEN result_code = 0 THEN '✓ DELETED AGAIN'
        ELSE '✗ ERROR'
    END as status
FROM sp_delete_anagrafica_transazionale(
    (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID),  -- ID paziente
    'test_admin',                         -- Cancellato da
    'Test cancellazione dopo ripristino', -- Motivo cancellazione
    'test_session_delete2',               -- ID sessione
    '127.0.0.1'::INET,                   -- Indirizzo IP
    'TestScript/1.0'                      -- User agent
);
*/