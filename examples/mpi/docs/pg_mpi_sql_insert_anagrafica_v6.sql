-- ========================================
-- SIMPLE TEST INSERT ANAGRAFICA - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- Test semplice con dati precompilati
-- ========================================

-- ⚠️  NOTA PER PRODUZIONE:
-- Questo script usa un UUID FISSO per test. In produzione utilizzare:
-- 
-- OPZIONE 1: UUID generato da PostgreSQL
-- gen_random_uuid()
--
-- OPZIONE 2: UUID generato dall'applicazione  
-- uuid.uuid4() in Python, UUID.randomUUID() in Java, crypto.randomUUID() in Node.js
--
-- OPZIONE 3: UUID basato su timestamp + identificatore univoco
-- CONCAT(EXTRACT(EPOCH FROM NOW()), '-', pg_backend_pid(), '-', random())
-- 
-- Il test usa UUID fisso per compatibilità con script DELETE e UPDATE

-- Test inserimento anagrafica con dati di esempio
SELECT 
    id_paziente,
    result_code,
    result_message,
    CASE 
        WHEN result_code = 0 THEN '✓ SUCCESS'
        WHEN result_code = 1008 THEN '✗ ERROR - CF già in uso da paziente attivo'
        WHEN result_code = 1009 THEN '⚠ WARNING - CF appartiene a paziente cancellato - SUGGERIMENTO: Utilizzare funzione ripristino'
        ELSE '✗ ERROR'
    END as status
FROM sp_insert_anagrafica_transazionale(
    -- Parametri anagrafica principale
    'f47ac10b-58cc-4372-a567-0e02b2c3d999'::UUID,   -- UID paziente (FISSO per test)
    'Mario',                                          -- Nome
    'Giuseppe',                                       -- Secondo nome
    '1980-01-15'::DATE,                              -- Data nascita
    'M',                                             -- Sesso
    'Roma',                                          -- Città nascita
    '058091',                                        -- Codice ISTAT nascita
    'RM',                                            -- Provincia nascita
    'ITA',                                           -- Nazione nascita
    TRUE,                                            -- Consenso privacy
    
    -- Parametri dati sensibili
    'RSSMRA80A15H501X',                             -- Codice fiscale
    'Rossi',                                         -- Cognome
    NULL,                                            -- Secondo cognome
    
    -- Parametri contatto/residenza
    '333-1234567',                                   -- Cellulare
    '06-12345678',                                   -- Telefono
    'mario.rossi@example.com',                       -- Email
    'Via Roma 123',                                  -- Indirizzo residenza
    'Roma',                                          -- Città residenza
    'RM',                                            -- Provincia residenza
    '00100',                                         -- CAP residenza
    1,                                               -- ID tipo documento
    'CI123456',                                      -- Numero documento
    '2020-01-01'::DATE,                             -- Data rilascio
    '2030-01-01'::DATE,                             -- Data scadenza
    
    -- Parametri dominio sanitario
    10,                                               -- ID dominio (DEFAULT)
    'EXT_MARIO_001',                                 -- ID esterno paziente
    
    -- Parametri audit
    'test_user',                                     -- Creato da
    'test_session_001',                              -- ID sessione
    '127.0.0.1'::INET,                              -- Indirizzo IP
    'TestScript/1.0'                                 -- User agent
);