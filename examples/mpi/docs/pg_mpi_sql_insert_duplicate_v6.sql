-- ========================================
-- SCRIPT TEST CREAZIONE DUPLICATI POTENZIALI
-- Crea 2 record simili per testare rilevamento duplicati
-- ========================================

-- ========================================
-- 1. INSERIMENTO PAZIENTE ORIGINALE (Mario Rossi)
-- ========================================

SELECT * FROM sp_insert_anagrafica_transazionale(
    -- Anagrafica
    'f47ac10b-58cc-4372-a567-0e02b2c3d001'::UUID, 
    'Mario', 
    'Giuseppe', 
    '1980-01-15'::DATE, 
    'M',
    'Roma', 
    '058091', 
    'RM', 
    'ITA', 
    TRUE,
    
    -- Dati sensibili
    'RSSMRA80A15H501Y', 
    'Rossi', 
    NULL,
    
    -- Contatti
    '333-1234567', 
    '06-12345678', 
    'mario.rossi@example.com', 
    'Via Roma 123', 
    'Roma', 
    'RM', 
    '00100', 
    1, 
    'CI123456', 
    '2020-01-01'::DATE, 
    '2030-01-01'::DATE,
    
    -- Dominio
    10, 
    'EXT_MARIO_DUP_001',
    
    -- Audit
    'test_user_duplicates', 
    'test_session_001', 
    '192.168.1.100'::INET, 
    'TestDuplicates/1.0'
);

-- ========================================
-- 2. INSERIMENTO POTENZIALE DUPLICATO (Variazioni minori)
-- ========================================

SELECT * FROM sp_insert_anagrafica_transazionale(
    -- Anagrafica - MODIFICHE per creare conflitto
    'f47ac10b-58cc-4372-a567-0e02b2c3d002'::UUID, -- UUID diverso (obbligatorio)
    'Mario Giuseppe',  -- Nome esteso vs "Mario" + secondo_nome "Giuseppe"
    NULL,              -- Secondo nome NULL vs "Giuseppe"
    '1980-01-15'::DATE, -- Data nascita IDENTICA (match perfetto)
    'M',               -- Sesso identico
    'ROMA',            -- Città nascita MAIUSCOLO vs "Roma"
    '058091',          -- Codice ISTAT identico
    'RM',              -- Provincia identica
    'ITA',             -- Nazione identica
    TRUE,              -- Consenso identico
    
    -- Dati sensibili - CODICE FISCALE DIVERSO per evitare blocco insert
    'RSSMRA80A15H501W', -- CF simile ma ultima lettera diversa
    'Rossi',            -- Cognome identico
    NULL,               -- Secondo cognome NULL
    
    -- Contatti - LEGGERE VARIAZIONI
    '333-1234567',                    -- Cellulare identico
    '06-87654321',                    -- Telefono DIVERSO
    'mario.giuseppe.rossi@gmail.com', -- Email DIVERSA ma simile
    'Via Roma 123, Interno 5',        -- Indirizzo simile ma più specifico
    'Roma',                           -- Città residenza identica
    'RM',                             -- Provincia identica
    '00100',                          -- CAP identico
    1,                                -- Tipo documento identico
    'CI654321',                       -- Documento DIVERSO
    '2021-01-01'::DATE,               -- Data rilascio diversa
    '2031-01-01'::DATE,               -- Data scadenza diversa
    
    -- Dominio
    10,                  -- Stesso dominio sanitario
    'EXT_MARIO_DUP_002',    -- ID esterno diverso
    
    -- Audit
    'test_user_duplicates', 
    'test_session_002', 
    '192.168.1.101'::INET, 
    'TestDuplicates/1.0'
);

-- ========================================
-- 3. INSERIMENTO TERZO CASO LIMITE (Anna Bianchi simile)
-- ========================================

SELECT * FROM sp_insert_anagrafica_transazionale(
    -- Anagrafica
    'f47ac10b-58cc-4372-a567-0e02b2c3d003'::UUID,
    'Anna',
    'Maria',
    '1985-05-20'::DATE,
    'F',
    'Milano',
    '015146',
    'MI',
    'ITA',
    TRUE,
    
    -- Dati sensibili
    'BNCNNA85E60F205X',
    'Bianchi',
    NULL,
    
    -- Contatti
    '338-7654321',
    '02-12345678',
    'anna.bianchi@email.com',
    'Via Milano 45',
    'Milano',
    'MI',
    '20100',
    1,
    'CI789012',
    '2019-01-01'::DATE,
    '2029-01-01'::DATE,
    
    -- Dominio
    10,
    'EXT_ANNA_DUP_001',
    
    -- Audit
    'test_user_duplicates',
    'test_session_003',
    '192.168.1.102'::INET,
    'TestDuplicates/1.0'
);

-- ========================================
-- 4. INSERIMENTO DUPLICATO DI ANNA (Variazioni)
-- ========================================

SELECT * FROM sp_insert_anagrafica_transazionale(
    -- Anagrafica - Simile ad Anna ma con variazioni
    'f47ac10b-58cc-4372-a567-0e02b2c3d004'::UUID,
    'Anna Maria',       -- Nome composto vs separato
    NULL,               -- Secondo nome NULL
    '1985-05-20'::DATE, -- Data nascita IDENTICA
    'F',                -- Sesso identico
    'Milano',           -- Luogo nascita identico
    '015146',           -- Codice ISTAT identico
    'MI',               -- Provincia identica
    'ITA',              -- Nazione identica
    TRUE,               -- Consenso identico
    
    -- Dati sensibili - CF DIVERSO ma simile
    'BNCNNA85E60F205W', -- CF con ultima lettera diversa (errore tipico)
    'Bianchi',          -- Cognome identico
    'De',               -- Secondo cognome aggiunto
    
    -- Contatti
    '338-7654321',           -- Cellulare identico
    NULL,                    -- Telefono NULL
    'a.bianchi@gmail.com',   -- Email diversa ma riconducibile
    'Via Milano 45/A',       -- Indirizzo simile
    'Milano',                -- Città identica
    'MI',                    -- Provincia identica
    '20100',                 -- CAP identico
    1,                       -- Tipo documento CI
    'CI345678',              -- CI invece di Passaporto
    '2020-01-01'::DATE,      -- Date diverse
    '2030-01-01'::DATE,
    
    -- Dominio
    10,                       -- Stesso dominio
    'EXT_ANNA_DUP_002',          -- ID esterno diverso
    
    -- Audit
    'test_user_duplicates',
    'test_session_004',
    '192.168.1.103'::INET,
    'TestDuplicates/1.0'
);

-- ========================================
-- VERIFICA INSERIMENTI
-- ========================================

-- Mostra tutti i pazienti inseriti
SELECT 
    ap.id,
    ap.uid,
    ap.nome,
    ap.secondo_nome,
    ap.data_nascita,
    ap.sesso,
    ap.citta_nascita,
    ds.codice_fiscale_hash,
    dcr.email,
    dcr.cellulare
FROM anagrafiche_pazienti ap
LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
LEFT JOIN dati_contatto_residenza dcr ON ap.id = dcr.id_paziente AND dcr.attivo = TRUE
WHERE ap.creato_da = 'test_user_duplicates'
ORDER BY ap.data_creazione;

-- Verifica coda scan duplicati
SELECT 
    dsq.id,
    dsq.id_paziente,
    dsq.stato,
    dsq.priorita,
    dsq.data_creazione,
    ap.nome,
    ap.data_nascita
FROM duplicate_scan_queue dsq
JOIN anagrafiche_pazienti ap ON dsq.id_paziente = ap.id
WHERE ap.creato_da = 'test_user_duplicates'
ORDER BY dsq.data_creazione;