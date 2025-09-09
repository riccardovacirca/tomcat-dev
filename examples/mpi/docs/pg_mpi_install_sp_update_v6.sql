-- ========================================
-- STORED PROCEDURES UPDATE v6.0 - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- GESTIONE TRANSAZIONALE UPDATE ANAGRAFICA CON AUDIT
-- COMPATIBILITÀ: PostgreSQL 12+
-- ========================================

-- ========================================
-- STORED PROCEDURE UPDATE ANAGRAFICA TRANSAZIONALE
-- ========================================

DROP FUNCTION IF EXISTS sp_update_anagrafica_transazionale(
    BIGINT, VARCHAR(64), VARCHAR(64), DATE, CHAR(1), VARCHAR(128), VARCHAR(6), VARCHAR(4), VARCHAR(3), BOOLEAN, DATE, TIME, VARCHAR(128),
    VARCHAR(16), VARCHAR(64), VARCHAR(64),
    VARCHAR(20), VARCHAR(20), VARCHAR(254), VARCHAR(256), VARCHAR(128), VARCHAR(4), VARCHAR(10), INTEGER, VARCHAR(64), DATE, DATE, VARCHAR(3),
    VARCHAR(128), VARCHAR(128), INET, VARCHAR(512)
);

CREATE OR REPLACE FUNCTION sp_update_anagrafica_transazionale(
    -- Identificativo paziente (obbligatorio)
    p_id_paziente BIGINT,
    
    -- Parametri anagrafica principale (NULL = non modificare)
    p_nome VARCHAR(64),
    p_secondo_nome VARCHAR(64),
    p_data_nascita DATE,
    p_sesso CHAR(1),
    p_citta_nascita VARCHAR(128),
    p_codice_istat_nascita VARCHAR(6),
    p_provincia_nascita VARCHAR(4),
    p_nazione_nascita VARCHAR(3),
    p_consenso_privacy BOOLEAN,
    p_data_decesso DATE,
    p_ora_decesso TIME,
    p_luogo_decesso VARCHAR(128),
    
    -- Parametri dati sensibili (NULL = non modificare)
    p_codice_fiscale VARCHAR(16),
    p_cognome VARCHAR(64),
    p_secondo_cognome VARCHAR(64),
    
    -- Parametri contatto/residenza (NULL = non modificare)
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
    p_cittadinanza VARCHAR(3),
    
    -- Parametri audit
    p_id_sessione VARCHAR(128),
    p_indirizzo_ip INET,
    p_user_agent VARCHAR(512)
)
RETURNS TABLE(
    rows_affected INTEGER,
    result_code INTEGER,
    result_message VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- Dichiarazione variabili locali
    v_paziente_exists INTEGER DEFAULT 0;
    v_versione_corrente INTEGER DEFAULT 0;
    v_uid_paziente UUID;
    v_encryption_key TEXT DEFAULT 'mpi_encryption_key_2025';
    
    -- Snapshot dati precedenti per audit
    v_old_anagrafica JSONB DEFAULT NULL;
    v_old_sensibili JSONB DEFAULT NULL;
    v_old_contatti JSONB DEFAULT NULL;
    v_new_data JSONB DEFAULT NULL;
    v_modified_fields JSONB DEFAULT '[]'::JSONB;
    
    -- Variabili per controlli validazione
    v_sesso_valido INTEGER DEFAULT 0;
    v_cf_hash_nuovo VARCHAR(255);
    v_cf_duplicato INTEGER DEFAULT 0;
    v_cf_hash_vecchio VARCHAR(255);
    
    -- Contatori per righe modificate
    v_rows_anagrafica INTEGER DEFAULT 0;
    v_rows_sensibili INTEGER DEFAULT 0;
    v_rows_contatti INTEGER DEFAULT 0;
    v_total_rows INTEGER DEFAULT 0;
    
    -- Variabili per gestione errori
    v_sqlstate TEXT;
    v_error_message TEXT;

BEGIN
    -- ========================================
    -- VALIDAZIONI PRELIMINARI
    -- ========================================
    
    -- Controllo parametri obbligatori
    IF p_id_paziente IS NULL OR p_id_paziente <= 0 THEN
        rows_affected := 0;
        result_code := 2001;
        result_message := 'ERRORE: ID paziente obbligatorio e deve essere > 0';
        RETURN NEXT;
        RETURN;
    END IF;
    
    IF p_id_sessione IS NULL OR LENGTH(TRIM(p_id_sessione)) = 0 THEN
        rows_affected := 0;
        result_code := 2002;
        result_message := 'ERRORE: Campo id_sessione obbligatorio';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Validazione sesso (se specificato)
    IF p_sesso IS NOT NULL THEN
        SELECT COUNT(*) INTO v_sesso_valido 
        FROM codici_genere 
        WHERE codice = p_sesso AND attivo = TRUE;
        
        IF v_sesso_valido = 0 THEN
            rows_affected := 0;
            result_code := 2003;
            result_message := CONCAT('ERRORE: Codice sesso non valido: ', p_sesso);
            RETURN NEXT;
            RETURN;
        END IF;
    END IF;
    
    -- Validazione email (se specificata)
    IF p_email IS NOT NULL AND LENGTH(TRIM(p_email)) > 0 
       AND p_email !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
        rows_affected := 0;
        result_code := 2004;
        result_message := 'ERRORE: Formato email non valido';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- ========================================
    -- INIZIO TRANSAZIONE ATOMICA CON EXCEPTION HANDLER
    -- ========================================
    
    BEGIN
        -- ========================================
        -- VERIFICA ESISTENZA E LETTURA DATI CORRENTI
        -- ========================================
        
        SELECT COUNT(*), MAX(versione), uid
        INTO v_paziente_exists, v_versione_corrente, v_uid_paziente
        FROM anagrafiche_pazienti 
        WHERE id = p_id_paziente AND stato_merge = 'ATTIVO' AND attivo = TRUE
        GROUP BY uid;
        
        IF v_paziente_exists = 0 THEN
            rows_affected := 0;
            result_code := 2404;
            result_message := 'ERRORE: Paziente non trovato o non attivo';
            RETURN NEXT;
            RETURN;
        END IF;
        
        -- ========================================
        -- SNAPSHOT DATI PRECEDENTI PER AUDIT
        -- ========================================
        
        -- Anagrafica principale
        SELECT jsonb_build_object(
            'id', a.id,
            'uid', a.uid,
            'nome', a.nome,
            'secondo_nome', a.secondo_nome,
            'data_nascita', a.data_nascita,
            'sesso', a.sesso,
            'citta_nascita', a.citta_nascita,
            'codice_istat_nascita', a.codice_istat_nascita,
            'provincia_nascita', a.provincia_nascita,
            'nazione_nascita', a.nazione_nascita,
            'consenso_privacy', a.consenso_privacy,
            'data_consenso_privacy', a.data_consenso_privacy,
            'data_decesso', a.data_decesso,
            'ora_decesso', a.ora_decesso,
            'luogo_decesso', a.luogo_decesso,
            'versione', a.versione
        ) INTO v_old_anagrafica
        FROM anagrafiche_pazienti a
        WHERE a.id = p_id_paziente;
        
        -- Dati sensibili precedenti
        SELECT jsonb_build_object(
            'codice_fiscale_hash', ds.codice_fiscale_hash,
            'cognome_hash', ds.cognome_hash,
            'secondo_cognome_hash', ds.secondo_cognome_hash
        ) INTO v_old_sensibili
        FROM dati_sensibili_pazienti ds
        WHERE ds.id_paziente = p_id_paziente;
        
        -- Dati contatto precedenti
        SELECT jsonb_build_object(
            'cellulare', dcr.cellulare,
            'telefono', dcr.telefono,
            'email', dcr.email,
            'indirizzo_residenza', dcr.indirizzo_residenza,
            'citta_residenza', dcr.citta_residenza,
            'provincia_residenza', dcr.provincia_residenza,
            'cap_residenza', dcr.cap_residenza,
            'id_tipo_documento', dcr.id_tipo_documento,
            'numero_documento', dcr.numero_documento,
            'data_rilascio', dcr.data_rilascio,
            'data_scadenza', dcr.data_scadenza,
            'cittadinanza', dcr.cittadinanza
        ) INTO v_old_contatti
        FROM dati_contatto_residenza dcr
        WHERE dcr.id_paziente = p_id_paziente AND dcr.attivo = TRUE;
        
        -- ========================================
        -- CONTROLLO DUPLICATO CODICE FISCALE
        -- ========================================
        
        IF p_codice_fiscale IS NOT NULL THEN
            v_cf_hash_nuovo := ENCODE(DIGEST(UPPER(TRIM(p_codice_fiscale)), 'sha256'), 'hex');
            
            -- Ottieni hash CF corrente
            SELECT codice_fiscale_hash INTO v_cf_hash_vecchio
            FROM dati_sensibili_pazienti 
            WHERE id_paziente = p_id_paziente;
            
            -- Controlla duplicato solo se CF è cambiato
            IF v_cf_hash_nuovo != COALESCE(v_cf_hash_vecchio, '') THEN
                SELECT COUNT(*) INTO v_cf_duplicato 
                FROM dati_sensibili_pazienti 
                WHERE codice_fiscale_hash = v_cf_hash_nuovo;
                
                IF v_cf_duplicato > 0 THEN
                    rows_affected := 0;
                    result_code := 2007;
                    result_message := 'ERRORE: Codice fiscale già registrato per altro paziente';
                    RETURN NEXT;
                    RETURN;
                END IF;
            END IF;
        END IF;
        
        -- ========================================
        -- 1. AGGIORNAMENTO ANAGRAFICA PRINCIPALE
        -- ========================================
        
        UPDATE anagrafiche_pazienti 
        SET 
            nome = CASE WHEN p_nome IS NOT NULL THEN TRIM(p_nome) ELSE nome END,
            secondo_nome = CASE WHEN p_secondo_nome IS NOT NULL THEN TRIM(p_secondo_nome) ELSE secondo_nome END,
            data_nascita = COALESCE(p_data_nascita, data_nascita),
            sesso = COALESCE(p_sesso, sesso),
            citta_nascita = CASE WHEN p_citta_nascita IS NOT NULL THEN TRIM(p_citta_nascita) ELSE citta_nascita END,
            codice_istat_nascita = COALESCE(p_codice_istat_nascita, codice_istat_nascita),
            provincia_nascita = COALESCE(p_provincia_nascita, provincia_nascita),
            nazione_nascita = COALESCE(p_nazione_nascita, nazione_nascita),
            consenso_privacy = COALESCE(p_consenso_privacy, consenso_privacy),
            data_consenso_privacy = CASE 
                WHEN p_consenso_privacy IS NOT NULL AND p_consenso_privacy = TRUE AND data_consenso_privacy IS NULL
                THEN NOW()
                WHEN p_consenso_privacy IS NOT NULL AND p_consenso_privacy = FALSE
                THEN NULL
                ELSE data_consenso_privacy 
            END,
            data_decesso = COALESCE(p_data_decesso, data_decesso),
            ora_decesso = COALESCE(p_ora_decesso, ora_decesso),
            luogo_decesso = CASE WHEN p_luogo_decesso IS NOT NULL THEN TRIM(p_luogo_decesso) ELSE luogo_decesso END,
            versione = versione + 1,
            data_modifica = NOW()
        WHERE id = p_id_paziente;
        
        GET DIAGNOSTICS v_rows_anagrafica = ROW_COUNT;
        
        -- ========================================
        -- 2. AGGIORNAMENTO DATI SENSIBILI
        -- ========================================
        
        IF p_codice_fiscale IS NOT NULL OR p_cognome IS NOT NULL OR p_secondo_cognome IS NOT NULL THEN
            INSERT INTO dati_sensibili_pazienti (
                id_paziente,
                codice_fiscale_hash, 
                codice_fiscale_crittografato,
                cognome_hash, 
                cognome_crittografato,
                secondo_cognome_hash, 
                secondo_cognome_crittografato,
                data_creazione,
                data_modifica
            ) VALUES (
                p_id_paziente,
                CASE WHEN p_codice_fiscale IS NOT NULL 
                    THEN ENCODE(DIGEST(UPPER(TRIM(p_codice_fiscale)), 'sha256'), 'hex')
                    ELSE (SELECT codice_fiscale_hash FROM dati_sensibili_pazienti WHERE id_paziente = p_id_paziente) 
                END,
                CASE WHEN p_codice_fiscale IS NOT NULL 
                    THEN PGP_SYM_ENCRYPT(UPPER(TRIM(p_codice_fiscale)), v_encryption_key) 
                    ELSE (SELECT codice_fiscale_crittografato FROM dati_sensibili_pazienti WHERE id_paziente = p_id_paziente) 
                END,
                CASE WHEN p_cognome IS NOT NULL 
                    THEN ENCODE(DIGEST(UPPER(TRIM(p_cognome)), 'sha256'), 'hex')
                    ELSE (SELECT cognome_hash FROM dati_sensibili_pazienti WHERE id_paziente = p_id_paziente) 
                END,
                CASE WHEN p_cognome IS NOT NULL 
                    THEN PGP_SYM_ENCRYPT(TRIM(p_cognome), v_encryption_key) 
                    ELSE (SELECT cognome_crittografato FROM dati_sensibili_pazienti WHERE id_paziente = p_id_paziente) 
                END,
                CASE WHEN p_secondo_cognome IS NOT NULL 
                    THEN ENCODE(DIGEST(UPPER(TRIM(p_secondo_cognome)), 'sha256'), 'hex')
                    ELSE (SELECT secondo_cognome_hash FROM dati_sensibili_pazienti WHERE id_paziente = p_id_paziente) 
                END,
                CASE WHEN p_secondo_cognome IS NOT NULL 
                    THEN PGP_SYM_ENCRYPT(TRIM(p_secondo_cognome), v_encryption_key) 
                    ELSE (SELECT secondo_cognome_crittografato FROM dati_sensibili_pazienti WHERE id_paziente = p_id_paziente) 
                END,
                COALESCE((SELECT data_creazione FROM dati_sensibili_pazienti WHERE id_paziente = p_id_paziente), NOW()),
                NOW()
            ) ON CONFLICT (id_paziente) DO UPDATE SET
                codice_fiscale_hash = EXCLUDED.codice_fiscale_hash,
                codice_fiscale_crittografato = EXCLUDED.codice_fiscale_crittografato,
                cognome_hash = EXCLUDED.cognome_hash,
                cognome_crittografato = EXCLUDED.cognome_crittografato,
                secondo_cognome_hash = EXCLUDED.secondo_cognome_hash,
                secondo_cognome_crittografato = EXCLUDED.secondo_cognome_crittografato,
                data_modifica = NOW();
            
            GET DIAGNOSTICS v_rows_sensibili = ROW_COUNT;
        END IF;
        
        -- ========================================
        -- 3. AGGIORNAMENTO DATI CONTATTO/RESIDENZA
        -- ========================================
        
        IF p_cellulare IS NOT NULL OR p_telefono IS NOT NULL OR p_email IS NOT NULL 
           OR p_indirizzo_residenza IS NOT NULL OR p_citta_residenza IS NOT NULL 
           OR p_provincia_residenza IS NOT NULL OR p_cap_residenza IS NOT NULL
           OR p_id_tipo_documento IS NOT NULL OR p_numero_documento IS NOT NULL
           OR p_data_rilascio IS NOT NULL OR p_data_scadenza IS NOT NULL 
           OR p_cittadinanza IS NOT NULL THEN
            
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
                creato_da,
                data_modifica
            ) VALUES (
                p_id_paziente,
                CASE WHEN p_cellulare IS NOT NULL THEN TRIM(p_cellulare) 
                    ELSE (SELECT cellulare FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE) END,
                CASE WHEN p_telefono IS NOT NULL THEN TRIM(p_telefono) 
                    ELSE (SELECT telefono FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE) END,
                CASE WHEN p_email IS NOT NULL THEN LOWER(TRIM(p_email)) 
                    ELSE (SELECT email FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE) END,
                COALESCE(p_id_tipo_documento, (SELECT id_tipo_documento FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE)),
                CASE WHEN p_numero_documento IS NOT NULL THEN TRIM(p_numero_documento) 
                    ELSE (SELECT numero_documento FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE) END,
                COALESCE(p_data_rilascio, (SELECT data_rilascio FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE)),
                COALESCE(p_data_scadenza, (SELECT data_scadenza FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE)),
                'ITA',
                COALESCE(p_provincia_residenza, (SELECT provincia_residenza FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE)),
                CASE WHEN p_citta_residenza IS NOT NULL THEN TRIM(p_citta_residenza) 
                    ELSE (SELECT citta_residenza FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE) END,
                CASE WHEN p_indirizzo_residenza IS NOT NULL THEN TRIM(p_indirizzo_residenza) 
                    ELSE (SELECT indirizzo_residenza FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE) END,
                COALESCE(p_cap_residenza, (SELECT cap_residenza FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE)),
                COALESCE(p_cittadinanza, (SELECT cittadinanza FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE), 'ITA'),
                COALESCE((SELECT versione FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE), 0) + 1,
                TRUE,
                COALESCE((SELECT data_creazione FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE), NOW()),
                COALESCE((SELECT creato_da FROM dati_contatto_residenza WHERE id_paziente = p_id_paziente AND attivo = TRUE), p_id_sessione),
                NOW()
            ) ON CONFLICT (id_paziente) DO UPDATE SET
                cellulare = EXCLUDED.cellulare,
                telefono = EXCLUDED.telefono,
                email = EXCLUDED.email,
                id_tipo_documento = EXCLUDED.id_tipo_documento,
                numero_documento = EXCLUDED.numero_documento,
                data_rilascio = EXCLUDED.data_rilascio,
                data_scadenza = EXCLUDED.data_scadenza,
                nazione_residenza = EXCLUDED.nazione_residenza,
                provincia_residenza = EXCLUDED.provincia_residenza,
                citta_residenza = EXCLUDED.citta_residenza,
                indirizzo_residenza = EXCLUDED.indirizzo_residenza,
                cap_residenza = EXCLUDED.cap_residenza,
                cittadinanza = EXCLUDED.cittadinanza,
                versione = dati_contatto_residenza.versione + 1,
                data_modifica = NOW();
            
            GET DIAGNOSTICS v_rows_contatti = ROW_COUNT;
        END IF;
        
        -- ========================================
        -- 4. COSTRUZIONE DATI PER AUDIT
        -- ========================================
        
        -- Identificazione campi modificati
        v_modified_fields := '[]'::JSONB;
        IF p_nome IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"nome"'::JSONB;
        END IF;
        IF p_secondo_nome IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"secondo_nome"'::JSONB;
        END IF;
        IF p_data_nascita IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"data_nascita"'::JSONB;
        END IF;
        IF p_sesso IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"sesso"'::JSONB;
        END IF;
        IF p_cognome IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"cognome"'::JSONB;
        END IF;
        IF p_codice_fiscale IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"codice_fiscale"'::JSONB;
        END IF;
        IF p_cellulare IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"cellulare"'::JSONB;
        END IF;
        IF p_telefono IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"telefono"'::JSONB;
        END IF;
        IF p_email IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"email"'::JSONB;
        END IF;
        IF p_indirizzo_residenza IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"indirizzo_residenza"'::JSONB;
        END IF;
        IF p_data_decesso IS NOT NULL THEN 
            v_modified_fields := v_modified_fields || '"data_decesso"'::JSONB;
        END IF;
        
        -- Costruzione dati nuovi
        v_new_data := jsonb_build_object(
            'anagrafica', jsonb_build_object(
                'nome', p_nome,
                'secondo_nome', p_secondo_nome,
                'data_nascita', p_data_nascita,
                'sesso', p_sesso,
                'citta_nascita', p_citta_nascita,
                'consenso_privacy', p_consenso_privacy,
                'data_decesso', p_data_decesso,
                'ora_decesso', p_ora_decesso,
                'luogo_decesso', p_luogo_decesso
            ),
            'dati_sensibili', jsonb_build_object(
                'codice_fiscale_aggiornato', CASE WHEN p_codice_fiscale IS NOT NULL THEN TRUE ELSE FALSE END,
                'cognome_aggiornato', CASE WHEN p_cognome IS NOT NULL THEN TRUE ELSE FALSE END
            ),
            'contatti', jsonb_build_object(
                'cellulare', p_cellulare,
                'telefono', p_telefono,
                'email', p_email,
                'indirizzo_residenza', p_indirizzo_residenza,
                'citta_residenza', p_citta_residenza,
                'provincia_residenza', p_provincia_residenza
            ),
            'metadata', jsonb_build_object(
                'rows_anagrafica', v_rows_anagrafica,
                'rows_sensibili', v_rows_sensibili,
                'rows_contatti', v_rows_contatti,
                'versione_precedente', v_versione_corrente,
                'versione_nuova', v_versione_corrente + 1,
                'timestamp_update', NOW()
            )
        );
        
        -- ========================================
        -- 5. INSERIMENTO AUDIT ATOMICO
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
            p_id_paziente, 
            'UPDATE',
            jsonb_build_object(
                'anagrafica', v_old_anagrafica,
                'sensibili', v_old_sensibili,
                'contatti', v_old_contatti
            )::TEXT, 
            v_new_data::TEXT, 
            v_modified_fields::TEXT,
            p_id_sessione, 
            p_id_sessione, 
            p_indirizzo_ip, 
            p_user_agent,
            NOW()
        );
        
        -- ========================================
        -- RETURN DI SUCCESSO
        -- ========================================
        
        v_total_rows := v_rows_anagrafica + v_rows_sensibili + v_rows_contatti;
        rows_affected := v_total_rows;
        result_code := 0;
        result_message := CONCAT('SUCCESS: Anagrafica aggiornata. Righe modificate: ', v_total_rows, 
                                ' (Ana:', v_rows_anagrafica, ', Sens:', v_rows_sensibili, ', Cont:', v_rows_contatti, ')');
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
                    'SP_UPDATE_ANAGRAFICA_TRANSAZIONALE', 
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
            rows_affected := 0;
            result_code := CASE 
                WHEN v_sqlstate = '23505' THEN 2008  -- Unique violation
                WHEN v_sqlstate = '23503' THEN 2009  -- Foreign key violation
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
-- Esempio aggiornamento completo
SELECT * FROM sp_update_anagrafica_transazionale(
    -- ID paziente
    1234,
    
    -- Anagrafica (aggiorna nome e data nascita)
    'Mario Giuseppe', NULL, '1980-01-16', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    -- Dati sensibili (aggiorna cognome)
    NULL, 'Verdi', NULL,
    
    -- Contatti (aggiorna email e cellulare)
    '333-9876543', NULL, 'mario.verdi@newemail.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    -- Audit
    'api_user_002', 'sess_2025_def456', '192.168.1.101'::INET, 'MicroTools-API/1.0'
);

-- Esempio aggiornamento solo email
SELECT * FROM sp_update_anagrafica_transazionale(
    -- ID paziente
    1234,
    
    -- Anagrafica (tutto NULL = non modificare)
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    -- Dati sensibili (tutto NULL = non modificare)
    NULL, NULL, NULL,
    
    -- Contatti (solo email)
    NULL, NULL, 'mario.rossi.new@email.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    
    -- Audit
    'utente_portale', 'web_session_789', '10.0.0.50'::INET, 'Mozilla/5.0'
);

-- Esempio test con gestione errori
DO $$
DECLARE
    result_row RECORD;
BEGIN
    SELECT * INTO result_row FROM sp_update_anagrafica_transazionale(
        1234, 'Mario', NULL, '1980-01-15', 'M', NULL, NULL, NULL, NULL, TRUE, NULL, NULL, NULL,
        NULL, 'Rossi', NULL,
        '333-1234567', NULL, 'mario.updated@example.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'test_user', 'test_session', '127.0.0.1'::INET, 'TestClient/1.0'
    );
    
    IF result_row.result_code = 0 THEN
        RAISE NOTICE 'SUCCESS: Righe modificate = %, Messaggio = %', result_row.rows_affected, result_row.result_message;
    ELSE
        RAISE NOTICE 'ERROR: Codice = %, Messaggio = %', result_row.result_code, result_row.result_message;
    END IF;
END $$;
*/

-- ========================================
-- INDICI PER PERFORMANCE UPDATE
-- ========================================

-- Gli indici sono già presenti nello schema principale, ma verifichiamo:

-- Indice per ottimizzare lookup paziente (già presente come PRIMARY KEY)
-- CREATE INDEX IF NOT EXISTS idx_anagrafiche_id_lookup ON anagrafiche_pazienti (id);

-- Indice per ottimizzare controllo duplicati CF (già presente come uk_dati_sensibili_cf)
-- CREATE INDEX IF NOT EXISTS idx_dati_sensibili_cf_lookup ON dati_sensibili_pazienti (codice_fiscale_hash);

-- Indice per audit performance (già presenti nelle partizioni)
-- CREATE INDEX IF NOT EXISTS idx_audit_record_lookup ON log_audit_anagrafico (nome_tabella, id_record, operazione);