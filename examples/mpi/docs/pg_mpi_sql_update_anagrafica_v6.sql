-- ========================================
-- SIMPLE TEST UPDATE ANAGRAFICA - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- Test semplice con dati precompilati per modifica
-- ========================================

-- ⚠️  NOTA PER PRODUZIONE:
-- Questo script modifica il paziente inserito con UUID fisso di test.
-- In produzione recuperare l'ID tramite:
-- 1. Parametro dall'applicazione  
-- 2. Query di ricerca per nome/CF/altri campi univoci
-- 3. Chiave primaria nota dall'interfaccia utente
-- 
-- Il test modifica alcuni campi del paziente Mario per verificare la stored procedure UPDATE

-- Formato output migliorato
\x auto

-- ========================================
-- UPDATE ANAGRAFICA PAZIENTE
-- ========================================

\echo ''
\echo '========================================'
\echo 'UPDATE ANAGRAFICA PAZIENTE'
\echo 'Sistema MPI - PostgreSQL'
\echo '========================================'
\echo ''

-- Test update di alcuni campi del paziente esistente
SELECT 
    rows_affected,
    result_code,
    result_message,
    CASE 
        WHEN result_code = 0 THEN '✓ SUCCESS - Anagrafica aggiornata correttamente'
        WHEN result_code = 2404 THEN '✗ ERROR - Paziente non trovato o inattivo'
        WHEN result_code = 2403 THEN '✗ ERROR - Paziente in stato non modificabile'
        ELSE '✗ ERROR'
    END as status
FROM sp_update_anagrafica_transazionale(
    (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID),  -- ID paziente Mario di test
    
    -- Parametri anagrafica principale (alcuni modificati)
    'Mario Alessandro',                               -- Nome (MODIFICATO: aggiunto secondo nome)
    'Giuseppe',                                       -- Secondo nome
    '1980-01-15'::DATE,                              -- Data nascita (stessa)
    'M',                                             -- Sesso
    'Roma',                                          -- Città nascita
    '058091',                                        -- Codice ISTAT nascita
    'RM',                                            -- Provincia nascita
    'ITA',                                           -- Nazione nascita
    TRUE,                                            -- Consenso privacy
    NULL,                                            -- Data decesso
    NULL,                                            -- Ora decesso
    NULL,                                            -- Luogo decesso
    
    -- Parametri dati sensibili (stesso CF e cognome)
    'RSSMRA80A15H501X',                             -- Codice fiscale (stesso)
    'Rossi',                                         -- Cognome (stesso)
    'De',                                            -- Secondo cognome (NUOVO)
    
    -- Parametri contatto/residenza (alcuni modificati)
    '333-9876543',                                   -- Cellulare (MODIFICATO)
    '06-87654321',                                   -- Telefono (MODIFICATO)
    'mario.alessandro.rossi@newemail.com',           -- Email (MODIFICATA)
    'Via Roma 123, Interno 5A',                     -- Indirizzo residenza (MODIFICATO: più dettagliato)
    'Roma',                                          -- Città residenza
    'RM',                                            -- Provincia residenza
    '00100',                                         -- CAP residenza
    2,                                               -- ID tipo documento (MODIFICATO: da CI a Passaporto)
    'PS123456',                                      -- Numero documento (MODIFICATO)
    '2023-01-01'::DATE,                             -- Data rilascio (MODIFICATA)
    '2033-01-01'::DATE,                             -- Data scadenza (MODIFICATA)
    'ITA',                                           -- Cittadinanza
    
    -- Parametri audit
    'test_session_update_001',                      -- ID sessione
    '127.0.0.1'::INET,                             -- Indirizzo IP
    'TestScriptUpdate/1.0'                         -- User agent
);

-- ========================================
-- VERIFICA STATO DOPO UPDATE
-- ========================================

\echo ''
\echo 'Stato paziente dopo update:'

SELECT 
    id,
    uid,
    nome,
    secondo_nome,
    data_nascita,
    sesso,
    versione,
    attivo,
    stato_merge,
    data_modifica
FROM anagrafiche_pazienti 
WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID;

-- ========================================
-- DATI CONTATTO DOPO UPDATE
-- ========================================

\echo ''
\echo 'Dati contatto dopo update:'

SELECT 
    id,
    id_paziente,
    cellulare,
    telefono, 
    email,
    indirizzo_residenza,
    numero_documento,
    versione,
    attivo,
    data_modifica
FROM dati_contatto_residenza 
WHERE id_paziente = (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID)
  AND attivo = TRUE;

-- ========================================
-- ASSOCIAZIONI DOPO UPDATE
-- ========================================

\echo ''
\echo 'Associazioni paziente-dominio dopo update:'

SELECT 
    id,
    id_paziente,
    id_dominio,
    id_esterno,
    stato,
    data_modifica
FROM associazioni_paziente_dominio 
WHERE id_paziente = (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID);

-- ========================================
-- LOG AUDIT UPDATE
-- ========================================

\echo ''
\echo 'Log audit update (ultimi 3 record):'

SELECT 
    id,
    nome_tabella,
    id_record,
    operazione,
    id_utente,
    data_creazione,
    LEFT(valori_nuovi, 100) || '...' as valori_nuovi_preview
FROM log_audit_anagrafico 
WHERE id_record = (SELECT id FROM anagrafiche_pazienti WHERE uid = 'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID)
  AND operazione = 'UPDATE'
ORDER BY data_creazione DESC
LIMIT 3;

\echo ''
\echo '========================================'
\echo 'Riepilogo modifiche apportate:'
\echo '- Nome: Mario → Mario Alessandro'  
\echo '- Secondo cognome: NULL → De'
\echo '- Cellulare: 333-1234567 → 333-9876543'
\echo '- Telefono: 06-12345678 → 06-87654321'  
\echo '- Email: mario.rossi@example.com → mario.alessandro.rossi@newemail.com'
\echo '- Indirizzo: Via Roma 123 → Via Roma 123, Interno 5A'
\echo '- Documento: CI123456 → PS123456 (Passaporto)'
\echo '- ID Esterno: EXT_MARIO_001 → EXT_MARIO_001_UPDATED'
\echo '========================================'