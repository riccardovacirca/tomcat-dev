-- ========================================
-- STORED PROCEDURE SOFT DELETE v6.0 - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- GESTIONE TRANSAZIONALE SOFT DELETE ANAGRAFICA CON AUDIT
-- COMPATIBILITÀ: PostgreSQL 12+
-- ========================================

-- ========================================
-- STORED PROCEDURE SOFT DELETE ANAGRAFICA TRANSAZIONALE
-- ========================================

DROP FUNCTION IF EXISTS sp_delete_anagrafica_transazionale(
    BIGINT, VARCHAR(128), VARCHAR(128), VARCHAR(128), INET, VARCHAR(512)
);

CREATE OR REPLACE FUNCTION sp_delete_anagrafica_transazionale(
    -- Identificativo paziente (obbligatorio)
    p_id_paziente BIGINT,
    
    -- Parametri audit
    p_cancellato_da VARCHAR(128),
    p_motivo_cancellazione VARCHAR(128),
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
    v_rows_sensibili INTEGER DEFAULT 0;
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
        result_code := 3001;
        result_message := 'ERRORE: ID paziente obbligatorio e deve essere > 0';
        RETURN NEXT;
        RETURN;
    END IF;
    
    IF p_cancellato_da IS NULL OR LENGTH(TRIM(p_cancellato_da)) = 0 THEN
        rows_affected := 0;
        result_code := 3002;
        result_message := 'ERRORE: Campo cancellato_da obbligatorio';
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
        WHERE id = p_id_paziente AND attivo = TRUE
        GROUP BY uid, stato_merge;
        
        IF v_paziente_exists = 0 THEN
            rows_affected := 0;
            result_code := 3404;
            result_message := 'ERRORE: Paziente non trovato o già cancellato';
            RETURN NEXT;
            RETURN;
        END IF;
        
        -- Verifica se il paziente è già stato cancellato logicamente
        IF v_stato_corrente = 'ELIMINATO' THEN
            rows_affected := 0;
            result_code := 3403;
            result_message := 'ERRORE: Paziente già cancellato logicamente';
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
        -- 1. SOFT DELETE ANAGRAFICA PRINCIPALE
        -- ========================================
        
        UPDATE anagrafiche_pazienti 
        SET 
            attivo = FALSE,
            stato_merge = 'ELIMINATO',
            versione = versione + 1,
            data_modifica = NOW()
        WHERE id = p_id_paziente;
        
        GET DIAGNOSTICS v_rows_anagrafica = ROW_COUNT;
        
        -- ========================================
        -- 2. SOFT DELETE DATI CONTATTO/RESIDENZA
        -- ========================================
        
        UPDATE dati_contatto_residenza 
        SET 
            attivo = FALSE,
            versione = versione + 1,
            data_modifica = NOW()
        WHERE id_paziente = p_id_paziente AND attivo = TRUE;
        
        GET DIAGNOSTICS v_rows_contatti = ROW_COUNT;
        
        -- ========================================
        -- 3. SOFT DELETE ASSOCIAZIONI PAZIENTE-DOMINIO
        -- ========================================
        
        UPDATE associazioni_paziente_dominio 
        SET 
            stato = 'INATTIVO',
            data_modifica = NOW()
        WHERE id_paziente = p_id_paziente AND stato = 'ATTIVO';
        
        GET DIAGNOSTICS v_rows_associazioni = ROW_COUNT;
        
        -- NOTA: I dati sensibili NON vengono cancellati per motivi di audit e compliance
        
        -- ========================================
        -- 4. COSTRUZIONE DATI PER AUDIT
        -- ========================================
        
        -- Costruzione dati nuovi
        v_new_data := jsonb_build_object(
            'anagrafica', jsonb_build_object(
                'attivo', FALSE,
                'stato_merge', 'ELIMINATO',
                'data_cancellazione', NOW(),
                'cancellato_da', p_cancellato_da,
                'motivo_cancellazione', COALESCE(p_motivo_cancellazione, 'Cancellazione logica')
            ),
            'contatti', jsonb_build_object(
                'attivo', FALSE,
                'rows_affected', v_rows_contatti
            ),
            'associazioni', jsonb_build_object(
                'stato', 'INATTIVO',
                'rows_affected', v_rows_associazioni
            ),
            'metadata', jsonb_build_object(
                'rows_anagrafica', v_rows_anagrafica,
                'rows_contatti', v_rows_contatti,
                'rows_associazioni', v_rows_associazioni,
                'versione_precedente', v_versione_corrente,
                'versione_nuova', v_versione_corrente + 1,
                'timestamp_delete', NOW(),
                'tipo_operazione', 'SOFT_DELETE'
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
            'DELETE',
            v_old_anagrafica::TEXT, 
            v_new_data::TEXT, 
            v_modified_fields::TEXT,
            p_cancellato_da, 
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
        result_message := CONCAT('SUCCESS: Anagrafica cancellata logicamente. Righe modificate: ', v_total_rows, 
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
                    'SP_DELETE_ANAGRAFICA_TRANSAZIONALE', 
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
                WHEN v_sqlstate = '23505' THEN 3008  -- Unique violation
                WHEN v_sqlstate = '23503' THEN 3009  -- Foreign key violation
                ELSE 9999  -- Generic error
            END;
            result_message := CONCAT('ERRORE TRANSAZIONE: ', v_error_message);
            RETURN NEXT;
    END;

END;
$$;

-- ========================================
-- FUNZIONE DI UTILITÀ PER RIPRISTINO SOFT DELETE
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
    v_paziente_exists INTEGER DEFAULT 0;
    v_stato_corrente VARCHAR(20);
    v_total_rows INTEGER DEFAULT 0;
    v_sqlstate TEXT;
    v_error_message TEXT;

BEGIN
    -- Controllo parametri obbligatori
    IF p_id_paziente IS NULL OR p_id_paziente <= 0 THEN
        rows_affected := 0;
        result_code := 4001;
        result_message := 'ERRORE: ID paziente obbligatorio';
        RETURN NEXT;
        RETURN;
    END IF;
    
    BEGIN
        -- Verifica esistenza paziente cancellato
        SELECT COUNT(*), MAX(stato_merge)
        INTO v_paziente_exists, v_stato_corrente
        FROM anagrafiche_pazienti 
        WHERE id = p_id_paziente AND attivo = FALSE;
        
        IF v_paziente_exists = 0 OR v_stato_corrente != 'ELIMINATO' THEN
            rows_affected := 0;
            result_code := 4404;
            result_message := 'ERRORE: Paziente non trovato tra quelli cancellati';
            RETURN NEXT;
            RETURN;
        END IF;
        
        -- Ripristina anagrafica
        UPDATE anagrafiche_pazienti 
        SET 
            attivo = TRUE,
            stato_merge = 'ATTIVO',
            versione = versione + 1,
            data_modifica = NOW()
        WHERE id = p_id_paziente;
        
        GET DIAGNOSTICS v_total_rows = ROW_COUNT;
        
        -- Log audit ripristino
        INSERT INTO log_audit_anagrafico (
            nome_tabella, id_record, operazione,
            valori_precedenti, valori_nuovi, campi_modificati,
            id_utente, id_sessione, indirizzo_ip, user_agent, data_creazione
        ) VALUES (
            'anagrafiche_pazienti', p_id_paziente, 'RESTORE',
            jsonb_build_object('stato_merge', 'ELIMINATO', 'attivo', FALSE)::TEXT,
            jsonb_build_object('stato_merge', 'ATTIVO', 'attivo', TRUE)::TEXT,
            '["attivo", "stato_merge"]',
            p_ripristinato_da, p_id_sessione, p_indirizzo_ip, p_user_agent, NOW()
        );
        
        rows_affected := v_total_rows;
        result_code := 0;
        result_message := CONCAT('SUCCESS: Anagrafica ripristinata. ID: ', p_id_paziente);
        RETURN NEXT;
        
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS 
                v_sqlstate = RETURNED_SQLSTATE,
                v_error_message = MESSAGE_TEXT;
            
            rows_affected := 0;
            result_code := 9999;
            result_message := CONCAT('ERRORE RIPRISTINO: ', v_error_message);
            RETURN NEXT;
    END;

END;
$$;

-- ========================================
-- ESEMPI DI UTILIZZO
-- ========================================

/*
-- Esempio soft delete di un paziente
SELECT * FROM sp_delete_anagrafica_transazionale(
    1234,                                    -- ID paziente
    'admin_user',                           -- Cancellato da
    'Richiesta paziente',                   -- Motivo cancellazione
    'sess_2025_delete123',                  -- ID sessione
    '192.168.1.100'::INET,                -- IP
    'AdminPanel/1.0'                        -- User agent
);

-- Esempio ripristino di un paziente cancellato
SELECT * FROM sp_restore_anagrafica_transazionale(
    1234,                                   -- ID paziente
    'admin_user',                          -- Ripristinato da
    'sess_2025_restore456',                -- ID sessione
    '192.168.1.100'::INET,               -- IP
    'AdminPanel/1.0'                       -- User agent
);

-- Verifica stato dopo soft delete
SELECT 
    id, uid, nome, secondo_nome, attivo, stato_merge,
    data_cancellazione, cancellato_da, motivo_cancellazione
FROM anagrafiche_pazienti 
WHERE id = 1234;

-- Lista pazienti cancellati logicamente
SELECT 
    id, uid, nome, secondo_nome, 
    data_cancellazione, cancellato_da, motivo_cancellazione
FROM anagrafiche_pazienti 
WHERE attivo = FALSE AND stato_merge = 'ELIMINATO'
ORDER BY data_cancellazione DESC;
*/