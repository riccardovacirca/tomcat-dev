-- ========================================
-- SIMPLE SOFT DELETE ANAGRAFICA - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- Test semplice soft delete anagrafica paziente
-- ========================================

-- ⚠️  NOTA PER PRODUZIONE:
-- Questo script usa l'ID del paziente inserito con UUID fisso di test.
-- In produzione recuperare l'ID tramite:
-- 1. Parametro dall'applicazione
-- 2. Query di ricerca per nome/CF/altri campi univoci
-- 3. Variabile di sessione se disponibile
-- 
-- Il test elimina il paziente Mario inserito con script INSERT compatibile

-- Formato output migliorato
\x auto

-- ========================================
-- SOFT DELETE ANAGRAFICA PAZIENTE
-- ========================================

\echo ''
\echo '========================================'
\echo 'SOFT DELETE ANAGRAFICA PAZIENTE'
\echo 'Sistema MPI - PostgreSQL'
\echo '========================================'
\echo ''

-- Test soft delete di un paziente esistente (sostituire con ID reale)
SELECT 
    rows_affected,
    result_code,
    result_message,
    CASE 
        WHEN result_code = 0 THEN '✓ SUCCESS - Paziente cancellato logicamente (soft delete). Per reinserimento con stesso CF utilizzare funzione ripristino.'
        WHEN result_code = 3404 THEN '✗ ERROR - Paziente non trovato o già cancellato'
        WHEN result_code = 3403 THEN '✗ ERROR - Paziente già cancellato logicamente'
        ELSE '✗ ERROR'
    END as status
FROM sp_delete_anagrafica_transazionale(
    (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID),  -- ID paziente Mario di test
    'test_admin',                          -- Cancellato da
    'Test cancellazione logica',           -- Motivo cancellazione
    'test_session_delete',                 -- ID sessione
    '127.0.0.1'::INET,                    -- Indirizzo IP
    'TestScript/1.0'                       -- User agent
);

-- ========================================
-- VERIFICA STATO DOPO SOFT DELETE
-- ========================================

\echo ''
\echo 'Stato paziente dopo soft delete:'

SELECT 
    id,
    uid,
    nome,
    secondo_nome,
    attivo,
    stato_merge,
    versione
FROM anagrafiche_pazienti 
WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID
ORDER BY id DESC
LIMIT 1;

-- ========================================
-- DATI CONTATTO DOPO SOFT DELETE
-- ========================================

\echo ''
\echo 'Dati contatto dopo soft delete:'

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
-- ASSOCIAZIONI DOPO SOFT DELETE
-- ========================================

\echo ''
\echo 'Associazioni paziente-dominio dopo soft delete:'

SELECT 
    apd.id_paziente,
    apd.id_dominio,
    apd.id_esterno,
    apd.stato
FROM associazioni_paziente_dominio apd
WHERE apd.id_paziente = (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID)
ORDER BY apd.id_paziente DESC
LIMIT 5;

-- ========================================
-- LOG AUDIT DELL'OPERAZIONE
-- ========================================

\echo ''
\echo 'Log audit soft delete:'

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
  AND la.operazione = 'DELETE'
ORDER BY la.data_creazione DESC
LIMIT 1;

-- ========================================
-- LISTA PAZIENTI CANCELLATI LOGICAMENTE
-- ========================================

\echo ''
\echo 'Lista pazienti cancellati logicamente (ultimi 10):'

SELECT 
    id,
    uid,
    nome,
    secondo_nome,
    data_modifica as ultima_modifica
FROM anagrafiche_pazienti 
WHERE attivo = FALSE AND stato_merge = 'ELIMINATO'
ORDER BY data_modifica DESC
LIMIT 10;

-- ========================================
-- ESEMPIO RIPRISTINO (COMMENTATO)
-- ========================================

\echo ''
\echo 'Per ripristinare il paziente, eseguire:'
\echo 'SELECT * FROM sp_restore_anagrafica_transazionale(1, ''admin_user'', ''session_restore'', ''127.0.0.1''::INET, ''RestoreScript/1.0'');'

-- Decommentare per testare il ripristino:
/*
SELECT 
    rows_affected,
    result_code,
    result_message,
    CASE 
        WHEN result_code = 0 THEN '✓ RESTORED'
        ELSE '✗ ERROR'
    END as status
FROM sp_restore_anagrafica_transazionale(
    1,                                     -- ID paziente
    'test_admin',                         -- Ripristinato da
    'test_session_restore',               -- ID sessione
    '127.0.0.1'::INET,                   -- Indirizzo IP
    'TestScript/1.0'                      -- User agent
);
*/