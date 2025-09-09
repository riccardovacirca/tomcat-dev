-- Tabella per logging errori delle stored procedures
CREATE TABLE IF NOT EXISTS log_errori_audit (
  id BIGSERIAL PRIMARY KEY,
  operazione VARCHAR(64) NOT NULL,
  errore VARCHAR(128) NOT NULL,
  sqlstate VARCHAR(5) DEFAULT NULL,
  errno INTEGER DEFAULT NULL,
  messaggio TEXT,
  data_errore TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_log_errori_operazione ON log_errori_audit (operazione);
CREATE INDEX IF NOT EXISTS idx_log_errori_data ON log_errori_audit (data_errore);

-- ========================================
-- STORED PROCEDURE INSERT ANAGRAFICA TRANSAZIONALE
-- ========================================

DROP FUNCTION IF EXISTS sp_insert_anagrafica_transazionale(
    UUID, VARCHAR(64), VARCHAR(64), DATE, CHAR(1), VARCHAR(128), VARCHAR(6), VARCHAR(4), VARCHAR(3), BOOLEAN,
    VARCHAR(16), VARCHAR(64), VARCHAR(64),
    VARCHAR(20), VARCHAR(20), VARCHAR(254), VARCHAR(256), VARCHAR(128), VARCHAR(4), VARCHAR(10), INTEGER, VARCHAR(64), DATE, DATE,
    INTEGER, VARCHAR(64),
    VARCHAR(128), VARCHAR(128), INET, VARCHAR(512)
);

CREATE OR REPLACE FUNCTION sp_insert_anagrafica_transazionale(
    -- Parametri anagrafica principale
    p_uid UUID,
    p_nome VARCHAR(64),
    p_secondo_nome VARCHAR(64),
    p_data_nascita DATE,
    p_sesso CHAR(1),
    p_citta_nascita VARCHAR(128),
    p_codice_istat_nascita VARCHAR(6),
    p_provincia_nascita VARCHAR(4),
    p_nazione_nascita VARCHAR(3),
    p_consenso_privacy BOOLEAN,
    
    -- Parametri dati sensibili
    p_codice_fiscale VARCHAR(16),
    p_cognome VARCHAR(64),
    p_secondo_cognome VARCHAR(64),
    
    -- Parametri contatto/residenza
    p_cellulare VARCHAR(20),
    p_telefono VARCHAR(20),
    p_email VARCHAR(254),
    p_indirizzo_residenza VARCHAR(256),
    p_citta_residenza VARCHAR(128),
    p_provincia_residenza VARCHAR(4),
    p_cap_residenza VARCHAR(10),
    p_id_tipo_documento INTEGER,
    p_numero_documento VARCHAR(64),
    p_data_rilascio DATE,
    p_data_scadenza DATE,
    
    -- Parametri dominio sanitario
    p_id_dominio INTEGER,
    p_id_esterno VARCHAR(64),
    
    -- Parametri audit
    p_creato_da VARCHAR(128),
    p_id_sessione VARCHAR(128),
    p_indirizzo_ip INET,
    p_user_agent VARCHAR(512)
)
RETURNS TABLE(
    id_paziente BIGINT,
    result_code INTEGER,
    result_message VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- Dichiarazione variabili locali
    v_id_paziente BIGINT DEFAULT NULL;
    v_cognome_hash VARCHAR(255);
    v_cf_hash VARCHAR(255);
    v_audit_data JSONB;
    v_encryption_key TEXT DEFAULT 'mpi_encryption_key_2025';
    v_sesso_valido INTEGER DEFAULT 0;
    v_cf_duplicato INTEGER DEFAULT 0;
    v_email_valida INTEGER DEFAULT 1;
    v_dominio_valido INTEGER DEFAULT 0;
    v_sqlstate TEXT;
    v_errno INTEGER;
    v_error_message TEXT;

BEGIN
    -- ========================================
    -- VALIDAZIONI PRELIMINARI
    -- ========================================
    
    -- Controllo parametri obbligatori
    IF p_uid IS NULL THEN
        id_paziente := NULL;
        result_code := 1001;
        result_message := 'ERRORE: UID paziente obbligatorio';
        RETURN NEXT;
        RETURN;
    END IF;
    
    IF p_creato_da IS NULL OR LENGTH(TRIM(p_creato_da)) = 0 THEN
        id_paziente := NULL;
        result_code := 1002;
        result_message := 'ERRORE: Campo creato_da obbligatorio';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Validazione dominio sanitario
    IF p_id_dominio IS NULL THEN
        id_paziente := NULL;
        result_code := 1003;
        result_message := 'ERRORE: ID dominio sanitario obbligatorio';
        RETURN NEXT;
        RETURN;
    END IF;
    
    SELECT COUNT(*) INTO v_dominio_valido 
    FROM domini_sanitari 
    WHERE id = p_id_dominio AND attivo = TRUE;
    
    IF v_dominio_valido = 0 THEN
        id_paziente := NULL;
        result_code := 1004;
        result_message := CONCAT('ERRORE: Dominio sanitario non valido o inattivo: ', p_id_dominio);
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Validazione sesso
    SELECT COUNT(*) INTO v_sesso_valido 
    FROM codici_genere 
    WHERE codice = COALESCE(p_sesso, 'U') AND attivo = TRUE;
    
    IF v_sesso_valido = 0 THEN
        id_paziente := NULL;
        result_code := 1005;
        result_message := CONCAT('ERRORE: Codice sesso non valido: ', COALESCE(p_sesso, 'NULL'));
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Validazione email (se presente)
    IF p_email IS NOT NULL AND p_email !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
        id_paziente := NULL;
        result_code := 1006;
        result_message := 'ERRORE: Formato email non valido';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Controllo duplicato UID
    SELECT COUNT(*) INTO v_cf_duplicato 
    FROM anagrafiche_pazienti 
    WHERE uid = p_uid;
    
    IF v_cf_duplicato > 0 THEN
        id_paziente := NULL;
        result_code := 1007;
        result_message := 'ERRORE: UID paziente già esistente';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Controllo duplicato Codice Fiscale (se presente)
    IF p_codice_fiscale IS NOT NULL THEN
        v_cf_hash := ENCODE(DIGEST(UPPER(TRIM(p_codice_fiscale)), 'sha256'), 'hex');
        
        -- Verifica CF in pazienti ATTIVI
        SELECT COUNT(*) INTO v_cf_duplicato 
        FROM dati_sensibili_pazienti ds
        JOIN anagrafiche_pazienti ap ON ds.id_paziente = ap.id
        WHERE ds.codice_fiscale_hash = v_cf_hash 
          AND ap.attivo = TRUE;
        
        IF v_cf_duplicato > 0 THEN
            id_paziente := NULL;
            result_code := 1008;
            result_message := 'ERRORE: Codice fiscale già registrato in paziente attivo';
            RETURN NEXT;
            RETURN;
        END IF;
        
        -- Verifica CF in pazienti CANCELLATI (soft-deleted)
        SELECT COUNT(*) INTO v_cf_duplicato 
        FROM dati_sensibili_pazienti ds
        JOIN anagrafiche_pazienti ap ON ds.id_paziente = ap.id
        WHERE ds.codice_fiscale_hash = v_cf_hash 
          AND ap.attivo = FALSE 
          AND ap.stato_merge = 'ELIMINATO';
        
        IF v_cf_duplicato > 0 THEN
            id_paziente := NULL;
            result_code := 1009;
            result_message := 'WARNING: Esiste paziente cancellato con stesso CF. Utilizzare funzione ripristino invece di nuovo inserimento';
            RETURN NEXT;
            RETURN;
        END IF;
    END IF;
    
    -- ========================================
    -- INIZIO TRANSAZIONE ATOMICA CON EXCEPTION HANDLER
    -- ========================================
    
    BEGIN
        -- ========================================
        -- 1. INSERIMENTO ANAGRAFICA PRINCIPALE
        -- ========================================
        
        INSERT INTO anagrafiche_pazienti (
            uid, nome, secondo_nome, data_nascita, sesso,
            citta_nascita, codice_istat_nascita, provincia_nascita, nazione_nascita,
            consenso_privacy, data_consenso_privacy,
            stato_merge, versione, attivo,
            data_creazione, creato_da
        ) VALUES (
            p_uid, 
            TRIM(p_nome), 
            TRIM(p_secondo_nome), 
            p_data_nascita, 
            COALESCE(p_sesso, 'U'),
            TRIM(p_citta_nascita), 
            p_codice_istat_nascita, 
            p_provincia_nascita, 
            COALESCE(p_nazione_nascita, 'ITA'),
            COALESCE(p_consenso_privacy, FALSE), 
            CASE WHEN COALESCE(p_consenso_privacy, FALSE) = TRUE THEN NOW() ELSE NULL END,
            'ATTIVO', 
            1, 
            TRUE,
            NOW(), 
            p_creato_da
        ) RETURNING id INTO v_id_paziente;
        
        -- ========================================
        -- 2. INSERIMENTO DATI SENSIBILI CRITTOGRAFATI
        -- ========================================
        
        IF p_codice_fiscale IS NOT NULL THEN
            -- Preparazione hash per ricerca
            v_cf_hash := CASE 
                WHEN p_codice_fiscale IS NOT NULL 
                THEN ENCODE(DIGEST(UPPER(TRIM(p_codice_fiscale)), 'sha256'), 'hex')
                ELSE NULL 
            END;
            
            v_cognome_hash := CASE 
                WHEN p_cognome IS NOT NULL 
                THEN ENCODE(DIGEST(UPPER(TRIM(p_cognome)), 'sha256'), 'hex')
                ELSE NULL 
            END;
            
            INSERT INTO dati_sensibili_pazienti (
                id_paziente,
                codice_fiscale_hash, 
                codice_fiscale_crittografato,
                cognome_hash, 
                cognome_crittografato,
                secondo_cognome_hash, 
                secondo_cognome_crittografato,
                data_creazione
            ) VALUES (
                v_id_paziente,
                v_cf_hash,
                CASE 
                    WHEN p_codice_fiscale IS NOT NULL 
                    THEN PGP_SYM_ENCRYPT(UPPER(TRIM(p_codice_fiscale)), v_encryption_key)
                    ELSE NULL 
                END,
                v_cognome_hash,
                CASE 
                    WHEN p_cognome IS NOT NULL 
                    THEN PGP_SYM_ENCRYPT(TRIM(p_cognome), v_encryption_key)
                    ELSE NULL 
                END,
                CASE 
                    WHEN p_secondo_cognome IS NOT NULL 
                    THEN ENCODE(DIGEST(UPPER(TRIM(p_secondo_cognome)), 'sha256'), 'hex')
                    ELSE NULL 
                END,
                CASE 
                    WHEN p_secondo_cognome IS NOT NULL 
                    THEN PGP_SYM_ENCRYPT(TRIM(p_secondo_cognome), v_encryption_key)
                    ELSE NULL 
                END,
                NOW()
            );
        END IF;
        
        -- ========================================
        -- 3. INSERIMENTO DATI CONTATTO/RESIDENZA
        -- ========================================
        
        IF p_cellulare IS NOT NULL OR p_telefono IS NOT NULL OR p_email IS NOT NULL 
           OR p_indirizzo_residenza IS NOT NULL OR p_numero_documento IS NOT NULL THEN
            
            INSERT INTO dati_contatto_residenza (
                id_paziente, 
                cellulare, 
                telefono, 
                email,
                id_tipo_documento,
                numero_documento,
                data_rilascio,
                data_scadenza,
                nazione_residenza, 
                provincia_residenza, 
                citta_residenza,
                indirizzo_residenza, 
                cap_residenza,
                cittadinanza,
                versione, 
                attivo, 
                data_creazione, 
                creato_da
            ) VALUES (
                v_id_paziente,
                TRIM(p_cellulare), 
                TRIM(p_telefono), 
                LOWER(TRIM(p_email)),
                p_id_tipo_documento,
                TRIM(p_numero_documento),
                p_data_rilascio,
                p_data_scadenza,
                'ITA', 
                p_provincia_residenza, 
                TRIM(p_citta_residenza),
                TRIM(p_indirizzo_residenza), 
                p_cap_residenza,
                'ITA',
                1, 
                TRUE, 
                NOW(), 
                p_creato_da
            );
        END IF;
        
        -- ========================================
        -- 4. INSERIMENTO ASSOCIAZIONE DOMINIO SANITARIO
        -- ========================================
        
        INSERT INTO associazioni_paziente_dominio (
            id_paziente,
            id_dominio,
            id_esterno,
            stato,
            data_creazione,
            creato_da
        ) VALUES (
            v_id_paziente,
            p_id_dominio,
            COALESCE(TRIM(p_id_esterno), CONCAT('PAZ_', v_id_paziente)),
            'ATTIVO',
            NOW(),
            p_creato_da
        );
        
        -- ========================================
        -- 5. INSERIMENTO CODA SCAN DUPLICATI ASINCRONO
        -- ========================================
        
        INSERT INTO duplicate_scan_queue (
            id_paziente,
            priorita,
            stato,
            parametri_scan,
            creato_da
        ) VALUES (
            v_id_paziente,
            'NORMALE',  -- Priorità normale per inserimenti standard
            'PENDING',  -- In attesa di elaborazione
            jsonb_build_object(
                'trigger', 'INSERT_ANAGRAFICA',
                'timestamp', NOW(),
                'sessione', p_id_sessione
            ),
            p_creato_da
        );
        
        -- ========================================
        -- 6. COSTRUZIONE DATI PER AUDIT
        -- ========================================
        
        v_audit_data := jsonb_build_object(
            'anagrafica', jsonb_build_object(
                'uid', p_uid,
                'nome', p_nome,
                'secondo_nome', p_secondo_nome,
                'data_nascita', p_data_nascita,
                'sesso', COALESCE(p_sesso, 'U'),
                'citta_nascita', p_citta_nascita,
                'consenso_privacy', COALESCE(p_consenso_privacy, FALSE)
            ),
            'dati_sensibili', jsonb_build_object(
                'codice_fiscale_presente', CASE WHEN p_codice_fiscale IS NOT NULL THEN TRUE ELSE FALSE END,
                'cognome_presente', CASE WHEN p_cognome IS NOT NULL THEN TRUE ELSE FALSE END,
                'codice_fiscale_hash', v_cf_hash,
                'cognome_hash', v_cognome_hash
            ),
            'contatti', jsonb_build_object(
                'cellulare', p_cellulare,
                'telefono', p_telefono,
                'email', p_email,
                'indirizzo_residenza', p_indirizzo_residenza,
                'citta_residenza', p_citta_residenza,
                'provincia_residenza', p_provincia_residenza
            ),
            'dominio', jsonb_build_object(
                'id_dominio', p_id_dominio,
                'id_esterno', COALESCE(TRIM(p_id_esterno), CONCAT('PAZ_', v_id_paziente))
            ),
            'metadata', jsonb_build_object(
                'id_generato', v_id_paziente,
                'timestamp_creazione', NOW(),
                'versione_schema', 'v6.0'
            )
        );
        
        -- ========================================
        -- 7. INSERIMENTO AUDIT ATOMICO
        -- ========================================
        
        INSERT INTO log_audit_anagrafico (
            nome_tabella, 
            id_record, 
            operazione,
            valori_precedenti, 
            valori_nuovi, 
            campi_modificati,
            id_utente, 
            id_sessione, 
            indirizzo_ip, 
            user_agent,
            data_creazione
        ) VALUES (
            'anagrafiche_pazienti', 
            v_id_paziente, 
            'INSERT',
            NULL, 
            v_audit_data::TEXT, 
            jsonb_build_array('uid', 'nome', 'cognome', 'data_nascita', 'sesso', 'contatti', 'dominio')::TEXT,
            p_creato_da, 
            p_id_sessione, 
            p_indirizzo_ip, 
            p_user_agent,
            NOW()
        );
        
        -- ========================================
        -- RETURN DI SUCCESSO
        -- ========================================
        
        id_paziente := v_id_paziente;
        result_code := 0;
        result_message := CONCAT('SUCCESS: Anagrafica inserita con ID ', v_id_paziente);
        RETURN NEXT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Gestione errori PostgreSQL
            GET STACKED DIAGNOSTICS 
                v_sqlstate = RETURNED_SQLSTATE,
                v_error_message = MESSAGE_TEXT;
            
            -- Log errore per debugging
            BEGIN
                INSERT INTO log_errori_audit (
                    operazione, errore, sqlstate, errno, messaggio, data_errore
                ) VALUES (
                    'SP_INSERT_ANAGRAFICA_TRANSAZIONALE', 
                    'TRANSACTION_FAILED', 
                    v_sqlstate, 
                    NULL, 
                    v_error_message, 
                    NOW()
                );
            EXCEPTION WHEN OTHERS THEN
                -- Ignore logging errors to prevent infinite loops
            END;
            
            -- Return error result
            id_paziente := NULL;
            result_code := CASE 
                WHEN v_sqlstate = '23505' THEN 1008  -- Unique violation
                WHEN v_sqlstate = '23503' THEN 1009  -- Foreign key violation
                ELSE 9999  -- Generic error
            END;
            result_message := CONCAT('ERRORE TRANSAZIONE: ', v_error_message);
            RETURN NEXT;
    END;

END;
$$;

-- ========================================
-- ESEMPI DI UTILIZZO
-- ========================================

/*
-- Esempio chiamata con tutti i parametri
SELECT * FROM sp_insert_anagrafica_transazionale(
    -- Anagrafica
    'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID, 'Mario', 'Giuseppe', '1980-01-15', 'M',
    'Roma', '058091', 'RM', 'ITA', TRUE,
    
    -- Dati sensibili
    'RSSMRA80A15H501X', 'Rossi', NULL,
    
    -- Contatti
    '333-1234567', '06-12345678', 'mario.rossi@example.com', 
    'Via Roma 123', 'Roma', 'RM', '00100', 1, 'CI123456', '2020-01-01', '2030-01-01',
    
    -- Dominio
    1, 'EXT_001',
    
    -- Audit
    'api_user_001', 'sess_2025_abc123', '192.168.1.100'::INET, 'MicroTools-API/1.0'
);

-- Esempio chiamata con parametri minimi
SELECT * FROM sp_insert_anagrafica_transazionale(
    -- Anagrafica minima
    'f47ac10b-58cc-4372-a567-0e02b2c3d480'::UUID, 'Anna', NULL, '1985-05-20', 'F',
    NULL, NULL, NULL, NULL, NULL,
    
    -- Dati sensibili minimi
    NULL, 'Bianchi', NULL,
    
    -- Contatti minimi
    NULL, NULL, 'anna.bianchi@email.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    -- Dominio (obbligatorio)
    1, NULL,
    
    -- Audit
    'sistema_import', 'batch_001', '127.0.0.1'::INET, 'ImportScript/1.0'
);

-- Esempio test con gestione errori
DO $$
DECLARE
    result_row RECORD;
BEGIN
    SELECT * INTO result_row FROM sp_insert_anagrafica_transazionale(
        'f47ac10b-58cc-4372-a567-0e02b2c3d481'::UUID, 'Test', NULL, '1990-01-01', 'M',
        NULL, NULL, NULL, NULL, TRUE,
        'TESTCF90A01H501X', 'TestCognome', NULL,
        NULL, NULL, 'test@example.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        1, 'TEST_001',
        'test_user', 'test_session', '127.0.0.1'::INET, 'TestClient/1.0'
    );
    
    IF result_row.result_code = 0 THEN
        RAISE NOTICE 'SUCCESS: ID Paziente = %, Messaggio = %', result_row.id_paziente, result_row.result_message;
    ELSE
        RAISE NOTICE 'ERROR: Codice = %, Messaggio = %', result_row.result_code, result_row.result_message;
    END IF;
END $$;
*/

-- ========================================
-- INDICI PER PERFORMANCE STORED PROCEDURE
-- ========================================

-- Gli indici sono già presenti nello schema principale, ma verifichiamo:

-- Indice per ottimizzare controllo duplicati UID (già presente come uk_anagrafiche_uid)
-- CREATE INDEX IF NOT EXISTS idx_anagrafiche_uid_lookup ON anagrafiche_pazienti (uid);

-- Indice per ottimizzare controllo duplicati CF (già presente come uk_dati_sensibili_cf)
-- CREATE INDEX IF NOT EXISTS idx_dati_sensibili_cf_lookup ON dati_sensibili_pazienti (codice_fiscale_hash);

-- Indice per audit performance (già presenti nelle partizioni)
-- CREATE INDEX IF NOT EXISTS idx_audit_record_lookup ON log_audit_anagrafico (nome_tabella, id_record, operazione);

-- ========================================
-- FUNZIONE DI UTILITÀ PER DECRITTOGRAFIA
-- ========================================

CREATE OR REPLACE FUNCTION decrypt_sensitive_data(
    encrypted_data BYTEA,
    encryption_key TEXT DEFAULT 'mpi_encryption_key_2025'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF encrypted_data IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN PGP_SYM_DECRYPT(encrypted_data, encryption_key);
EXCEPTION
    WHEN OTHERS THEN
        RETURN '[DECRYPTION_ERROR]';
END;
$$;

-- Esempio utilizzo decrittografia:
-- SELECT id, decrypt_sensitive_data(codice_fiscale_crittografato) as cf_decrypted FROM dati_sensibili_pazienti WHERE id_paziente = 1;

-- ========================================
-- CODICI DI ERRORE STORED PROCEDURE
-- ========================================

/*
CODICI DI RITORNO DELLA STORED PROCEDURE:

SUCCESS:
- 0: Inserimento completato con successo

ERRORI VALIDAZIONE:
- 1001: UID paziente obbligatorio
- 1002: Campo creato_da obbligatorio  
- 1003: ID dominio sanitario obbligatorio
- 1004: Dominio sanitario non valido o inattivo
- 1005: Codice sesso non valido
- 1006: Formato email non valido
- 1007: UID paziente già esistente
- 1008: Codice fiscale già registrato in paziente ATTIVO
- 1009: WARNING - Paziente con stesso CF già CANCELLATO (suggerire ripristino)

ERRORI TRANSAZIONE:
- 9999: Errore generico nella transazione
- 1009: Foreign key violation
- 1008: Unique violation (quando sqlstate = '23505')

WORKFLOW CF DUPLICATI:
- Se result_code = 1008: BLOCCARE inserimento - CF in uso da paziente attivo
- Se result_code = 1009: SUGGERIRE ripristino - CF appartiene a paziente cancellato
- Se result_code = 0: PROCEDERE - Inserimento riuscito
*/