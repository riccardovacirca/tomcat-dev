-- ========================================
-- STORED PROCEDURE RESTORE v6.0 - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- GESTIONE TRANSAZIONALE RESTORE ANAGRAFICA CON AUDIT
-- COMPATIBILITÀ: PostgreSQL 12+
-- ========================================

-- ========================================
-- STORED PROCEDURE RESTORE ANAGRAFICA TRANSAZIONALE
-- ========================================

DROP FUNCTION IF EXISTS sp_restore_anagrafica_transazionale(
    BIGINT, VARCHAR(128), VARCHAR(128), INET, VARCHAR(512)
);

CREATE OR REPLACE FUNCTION sp_restore_anagrafica_transazionale(
    -- Identificativo paziente (obbligatorio)
    p_id_paziente BIGINT,
    
    -- Parametri audit
    p_ripristinato_da VARCHAR(128),
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
    v_stato_corrente VARCHAR(20);
    
    -- Snapshot dati precedenti per audit
    v_old_anagrafica JSONB DEFAULT NULL;
    v_new_data JSONB DEFAULT NULL;
    v_modified_fields JSONB DEFAULT '["attivo", "stato_merge"]'::JSONB;
    
    -- Contatori per righe modificate
    v_rows_anagrafica INTEGER DEFAULT 0;
    v_rows_contatti INTEGER DEFAULT 0;
    v_rows_associazioni INTEGER DEFAULT 0;
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
        result_code := 4001;
        result_message := 'ERRORE: ID paziente obbligatorio e deve essere > 0';
        RETURN NEXT;
        RETURN;
    END IF;
    
    IF p_ripristinato_da IS NULL OR LENGTH(TRIM(p_ripristinato_da)) = 0 THEN
        rows_affected := 0;
        result_code := 4002;
        result_message := 'ERRORE: Campo ripristinato_da obbligatorio';
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
        
        SELECT COUNT(*), MAX(versione), uid, stato_merge
        INTO v_paziente_exists, v_versione_corrente, v_uid_paziente, v_stato_corrente
        FROM anagrafiche_pazienti 
        WHERE id = p_id_paziente AND attivo = FALSE
        GROUP BY uid, stato_merge;
        
        IF v_paziente_exists = 0 THEN
            rows_affected := 0;
            result_code := 4404;
            result_message := 'ERRORE: Paziente non trovato tra quelli cancellati';
            RETURN NEXT;
            RETURN;
        END IF;
        
        -- Verifica se il paziente è nel giusto stato per il ripristino
        IF v_stato_corrente != 'ELIMINATO' THEN
            rows_affected := 0;
            result_code := 4403;
            result_message := CONCAT('ERRORE: Paziente non in stato ELIMINATO. Stato corrente: ', v_stato_corrente);
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
            'consenso_privacy', a.consenso_privacy,
            'versione', a.versione,
            'stato_merge', a.stato_merge,
            'attivo', a.attivo
        ) INTO v_old_anagrafica
        FROM anagrafiche_pazienti a
        WHERE a.id = p_id_paziente;
        
        -- ========================================
        -- 1. RESTORE ANAGRAFICA PRINCIPALE
        -- ========================================
        
        UPDATE anagrafiche_pazienti 
        SET 
            attivo = TRUE,
            stato_merge = 'ATTIVO',
            versione = versione + 1,
            data_modifica = NOW()
        WHERE id = p_id_paziente;
        
        GET DIAGNOSTICS v_rows_anagrafica = ROW_COUNT;
        
        -- ========================================
        -- 2. RESTORE DATI CONTATTO/RESIDENZA
        -- ========================================
        
        UPDATE dati_contatto_residenza 
        SET 
            attivo = TRUE,
            versione = versione + 1,
            data_modifica = NOW()
        WHERE id_paziente = p_id_paziente AND attivo = FALSE;
        
        GET DIAGNOSTICS v_rows_contatti = ROW_COUNT;
        
        -- ========================================
        -- 3. RESTORE ASSOCIAZIONI PAZIENTE-DOMINIO
        -- ========================================
        
        UPDATE associazioni_paziente_dominio 
        SET 
            stato = 'ATTIVO',
            data_modifica = NOW()
        WHERE id_paziente = p_id_paziente AND stato = 'INATTIVO';
        
        GET DIAGNOSTICS v_rows_associazioni = ROW_COUNT;
        
        -- ========================================
        -- 4. COSTRUZIONE DATI PER AUDIT
        -- ========================================
        
        -- Costruzione dati nuovi
        v_new_data := jsonb_build_object(
            'anagrafica', jsonb_build_object(
                'attivo', TRUE,
                'stato_merge', 'ATTIVO',
                'data_ripristino', NOW(),
                'ripristinato_da', p_ripristinato_da
            ),
            'contatti', jsonb_build_object(
                'attivo', TRUE,
                'rows_affected', v_rows_contatti
            ),
            'associazioni', jsonb_build_object(
                'stato', 'ATTIVO',
                'rows_affected', v_rows_associazioni
            ),
            'metadata', jsonb_build_object(
                'rows_anagrafica', v_rows_anagrafica,
                'rows_contatti', v_rows_contatti,
                'rows_associazioni', v_rows_associazioni,
                'versione_precedente', v_versione_corrente,
                'versione_nuova', v_versione_corrente + 1,
                'timestamp_restore', NOW(),
                'tipo_operazione', 'RESTORE'
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
            'RESTORE',
            v_old_anagrafica::TEXT, 
            v_new_data::TEXT, 
            v_modified_fields::TEXT,
            p_ripristinato_da, 
            p_id_sessione, 
            p_indirizzo_ip, 
            p_user_agent,
            NOW()
        );
        
        -- ========================================
        -- RETURN DI SUCCESSO
        -- ========================================
        
        v_total_rows := v_rows_anagrafica + v_rows_contatti + v_rows_associazioni;
        rows_affected := v_total_rows;
        result_code := 0;
        result_message := CONCAT('SUCCESS: Anagrafica ripristinata correttamente. Righe modificate: ', v_total_rows, 
                                ' (Ana:', v_rows_anagrafica, ', Cont:', v_rows_contatti, ', Assoc:', v_rows_associazioni, ')');
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
                    'SP_RESTORE_ANAGRAFICA_TRANSAZIONALE', 
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
                WHEN v_sqlstate = '23505' THEN 4008  -- Unique violation
                WHEN v_sqlstate = '23503' THEN 4009  -- Foreign key violation
                ELSE 9999  -- Generic error
            END;
            result_message := CONCAT('ERRORE TRANSAZIONE: ', v_error_message);
            RETURN NEXT;
    END;

END;
$$;

-- ========================================
-- FUNZIONE DI UTILITÀ PER CONTROLLO RIPRISTINABILITÀ
-- ========================================

DROP FUNCTION IF EXISTS sp_check_restore_eligibility(BIGINT);

CREATE OR REPLACE FUNCTION sp_check_restore_eligibility(
    p_id_paziente BIGINT
)
RETURNS TABLE(
    eligible BOOLEAN,
    reason_code INTEGER,
    reason_message VARCHAR(255),
    patient_info JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_paziente_exists INTEGER DEFAULT 0;
    v_stato_corrente VARCHAR(20);
    v_attivo BOOLEAN;
    v_uid UUID;
    v_nome VARCHAR(64);
    v_data_modifica TIMESTAMP;

BEGIN
    -- Controllo parametri
    IF p_id_paziente IS NULL OR p_id_paziente <= 0 THEN
        eligible := FALSE;
        reason_code := 4001;
        reason_message := 'ID paziente non valido';
        patient_info := NULL;
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Recupera informazioni paziente
    SELECT COUNT(*), MAX(attivo), MAX(stato_merge), MAX(uid), MAX(nome), MAX(data_modifica)
    INTO v_paziente_exists, v_attivo, v_stato_corrente, v_uid, v_nome, v_data_modifica
    FROM anagrafiche_pazienti 
    WHERE id = p_id_paziente
    GROUP BY id;
    
    -- Costruisci info paziente
    patient_info := jsonb_build_object(
        'id', p_id_paziente,
        'uid', v_uid,
        'nome', v_nome,
        'attivo', v_attivo,
        'stato_merge', v_stato_corrente,
        'data_modifica', v_data_modifica
    );
    
    -- Verifica eligibilità
    IF v_paziente_exists = 0 THEN
        eligible := FALSE;
        reason_code := 4404;
        reason_message := 'Paziente non trovato';
    ELSIF v_attivo = TRUE THEN
        eligible := FALSE;
        reason_code := 4405;
        reason_message := 'Paziente già attivo - ripristino non necessario';
    ELSIF v_stato_corrente != 'ELIMINATO' THEN
        eligible := FALSE;
        reason_code := 4406;
        reason_message := CONCAT('Paziente non in stato ELIMINATO (stato: ', v_stato_corrente, ')');
    ELSE
        eligible := TRUE;
        reason_code := 0;
        reason_message := 'Paziente eligible per ripristino';
    END IF;
    
    RETURN NEXT;
END;
$$;

-- ========================================
-- ESEMPI DI UTILIZZO
-- ========================================

/*
-- Esempio controllo eligibilità ripristino
SELECT * FROM sp_check_restore_eligibility(1234);

-- Esempio ripristino di un paziente cancellato
SELECT * FROM sp_restore_anagrafica_transazionale(
    1234,                                   -- ID paziente
    'admin_user',                          -- Ripristinato da
    'sess_2025_restore456',                -- ID sessione
    '192.168.1.100'::INET,               -- IP
    'AdminPanel/1.0'                       -- User agent
);

-- Verifica stato dopo ripristino
SELECT 
    id, uid, nome, secondo_nome, attivo, stato_merge,
    versione, data_modifica
FROM anagrafiche_pazienti 
WHERE id = 1234;

-- Lista pazienti ripristinabili
SELECT 
    ap.id, ap.uid, ap.nome, ap.secondo_nome, 
    ap.data_modifica as data_cancellazione,
    cer.eligible, cer.reason_message
FROM anagrafiche_pazienti ap
CROSS JOIN LATERAL sp_check_restore_eligibility(ap.id) cer
WHERE ap.attivo = FALSE AND ap.stato_merge = 'ELIMINATO'
ORDER BY ap.data_modifica DESC
LIMIT 10;

-- Storico operazioni restore
SELECT 
    la.id_record,
    la.id_utente as ripristinato_da,
    la.data_creazione as data_ripristino,
    la.valori_nuovi::jsonb -> 'metadata' ->> 'rows_anagrafica' as righe_modificate
FROM log_audit_anagrafico la
WHERE la.operazione = 'RESTORE'
ORDER BY la.data_creazione DESC
LIMIT 10;
*/