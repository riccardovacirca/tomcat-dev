-- ========================================
-- STORED PROCEDURES GESTIONE DUPLICATI v6.0 - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- GESTIONE ASINCRONA RILEVAMENTO DUPLICATI
-- COMPATIBILITÀ: PostgreSQL 12+
-- ========================================

-- ========================================
-- FUNZIONE SCAN DUPLICATI POST-INSERT
-- ========================================

DROP FUNCTION IF EXISTS sp_scan_duplicati_post_insert(BIGINT) CASCADE;

CREATE OR REPLACE FUNCTION sp_scan_duplicati_post_insert(
    p_id_paziente BIGINT
)
RETURNS TABLE(
    candidati_trovati INTEGER,
    result_code INTEGER,
    result_message VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- Variabili algoritmo
    v_algoritmo_id INTEGER;
    v_peso_nome DECIMAL(3,2);
    v_peso_cognome DECIMAL(3,2);
    v_peso_data_nascita DECIMAL(3,2);
    v_peso_codice_fiscale DECIMAL(3,2);
    v_peso_luogo_nascita DECIMAL(3,2);
    v_soglia_certo DECIMAL(4,2);
    v_soglia_probabile DECIMAL(4,2);
    
    -- Dati paziente da analizzare
    v_nome VARCHAR(64);
    v_data_nascita DATE;
    v_luogo_nascita VARCHAR(128);
    v_cognome_hash VARCHAR(255);
    v_cf_hash VARCHAR(255);
    v_creato_da VARCHAR(128);
    
    -- Contatori e risultati
    v_candidati_count INTEGER := 0;
    v_candidato RECORD;
    v_score_totale DECIMAL(5,2);
    v_candidato_id BIGINT;
    
BEGIN
    -- ========================================
    -- RECUPERA ALGORITMO ATTIVO
    -- ========================================
    
    SELECT id, peso_nome, peso_cognome, peso_data_nascita, peso_codice_fiscale, peso_luogo_nascita,
           soglia_duplicato_certo, soglia_duplicato_probabile
    INTO v_algoritmo_id, v_peso_nome, v_peso_cognome, v_peso_data_nascita, 
         v_peso_codice_fiscale, v_peso_luogo_nascita, v_soglia_certo, v_soglia_probabile
    FROM algoritmi_matching 
    WHERE attivo = TRUE 
    ORDER BY data_creazione DESC 
    LIMIT 1;
    
    IF v_algoritmo_id IS NULL THEN
        candidati_trovati := 0;
        result_code := 2001;
        result_message := 'ERRORE: Nessun algoritmo matching attivo configurato';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- ========================================
    -- RECUPERA DATI PAZIENTE DA ANALIZZARE
    -- ========================================
    
    SELECT ap.nome, ap.data_nascita, ap.citta_nascita, ap.creato_da,
           ds.cognome_hash, ds.codice_fiscale_hash
    INTO v_nome, v_data_nascita, v_luogo_nascita, v_creato_da,
         v_cognome_hash, v_cf_hash
    FROM anagrafiche_pazienti ap
    LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
    WHERE ap.id = p_id_paziente;
    
    IF NOT FOUND THEN
        candidati_trovati := 0;
        result_code := 2002;
        result_message := 'ERRORE: Paziente non trovato';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- ========================================
    -- RICERCA CANDIDATI DUPLICATI
    -- ========================================
    
    FOR v_candidato IN
        WITH potenziali_duplicati AS (
            SELECT 
                ap.id as id_candidato,
                -- Score per nome (similarità approssimativa)
                CASE 
                    WHEN ap.nome IS NOT NULL AND v_nome IS NOT NULL THEN
                        CASE 
                            WHEN UPPER(ap.nome) = UPPER(v_nome) THEN 100.0
                            WHEN UPPER(ap.nome) LIKE UPPER(v_nome) || '%' OR UPPER(v_nome) LIKE UPPER(ap.nome) || '%' THEN 80.0
                            WHEN POSITION(UPPER(SUBSTRING(ap.nome, 1, 3)) IN UPPER(v_nome)) > 0 THEN 60.0
                            ELSE 0.0
                        END * v_peso_nome
                    ELSE 0.0
                END as score_nome,
                
                -- Score per cognome (hash exact match)
                CASE 
                    WHEN ds.cognome_hash IS NOT NULL AND v_cognome_hash IS NOT NULL 
                         AND ds.cognome_hash = v_cognome_hash THEN 100.0 * v_peso_cognome
                    ELSE 0.0
                END as score_cognome,
                
                -- Score per data nascita
                CASE 
                    WHEN ap.data_nascita IS NOT NULL AND v_data_nascita IS NOT NULL 
                         AND ap.data_nascita = v_data_nascita THEN 100.0 * v_peso_data_nascita
                    ELSE 0.0
                END as score_data_nascita,
                
                -- Score per codice fiscale (hash exact match)
                CASE 
                    WHEN ds.codice_fiscale_hash IS NOT NULL AND v_cf_hash IS NOT NULL 
                         AND ds.codice_fiscale_hash = v_cf_hash THEN 100.0 * v_peso_codice_fiscale
                    ELSE 0.0
                END as score_codice_fiscale,
                
                -- Score per luogo nascita
                CASE 
                    WHEN ap.citta_nascita IS NOT NULL AND v_luogo_nascita IS NOT NULL 
                         AND UPPER(ap.citta_nascita) = UPPER(v_luogo_nascita) THEN 100.0 * v_peso_luogo_nascita
                    ELSE 0.0
                END as score_luogo_nascita
                
            FROM anagrafiche_pazienti ap
            LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
            WHERE ap.id != p_id_paziente  -- Esclude se stesso
              AND ap.stato_merge = 'ATTIVO'
              AND ap.attivo = TRUE
              -- Ottimizzazione: almeno un campo deve matchare per continuare
              AND (
                  (ap.nome IS NOT NULL AND UPPER(ap.nome) LIKE UPPER(SUBSTRING(v_nome, 1, 3)) || '%') OR
                  (ds.cognome_hash = v_cognome_hash) OR
                  (ds.codice_fiscale_hash = v_cf_hash) OR
                  (ap.data_nascita = v_data_nascita)
              )
        )
        SELECT 
            id_candidato,
            (score_nome + score_cognome + score_data_nascita + score_codice_fiscale + score_luogo_nascita) as score_totale
        FROM potenziali_duplicati
        WHERE (score_nome + score_cognome + score_data_nascita + score_codice_fiscale + score_luogo_nascita) >= v_soglia_probabile
        ORDER BY score_totale DESC
        LIMIT 10  -- Limita a massimo 10 candidati per performance
    LOOP
        v_score_totale := v_candidato.score_totale;
        
        -- Verifica che non sia già in blacklist
        IF NOT EXISTS (
            SELECT 1 FROM blacklist_merge 
            WHERE (id_paziente_1 = p_id_paziente AND id_paziente_2 = v_candidato.id_candidato)
               OR (id_paziente_1 = v_candidato.id_candidato AND id_paziente_2 = p_id_paziente)
               AND attivo = TRUE
        ) THEN
            -- Verifica che non sia già un candidato duplicato esistente
            IF NOT EXISTS (
                SELECT 1 FROM candidati_duplicati 
                WHERE (id_paziente_primario = v_candidato.id_candidato AND id_paziente_candidato = p_id_paziente)
                   OR (id_paziente_primario = p_id_paziente AND id_paziente_candidato = v_candidato.id_candidato)
                   AND stato NOT IN ('RESPINTO', 'MERGIATO')
            ) THEN
                -- Inserisci candidato duplicato
                INSERT INTO candidati_duplicati (
                    id_paziente_primario,
                    id_paziente_candidato,
                    id_algoritmo,
                    score_matching,
                    tipo_rilevamento,
                    stato,
                    priorita,
                    note_revisore,
                    data_creazione
                ) VALUES (
                    v_candidato.id_candidato,  -- Paziente esistente (primario)
                    p_id_paziente,             -- Nuovo paziente (candidato)
                    v_algoritmo_id,
                    v_score_totale,
                    'AUTOMATICO'::tipo_rilevamento_type,
                    CASE 
                        WHEN v_score_totale >= v_soglia_certo THEN 'CONFERMATO'::stato_candidato_type
                        ELSE 'NUOVO'::stato_candidato_type
                    END,
                    CASE 
                        WHEN v_score_totale >= v_soglia_certo THEN 'ALTA'::priorita_type
                        WHEN v_score_totale >= (v_soglia_probabile + 10) THEN 'MEDIA'::priorita_type
                        ELSE 'BASSA'::priorita_type
                    END,
                    CONCAT('Auto-rilevato con score ', v_score_totale::TEXT, '%'),
                    NOW()
                ) RETURNING id INTO v_candidato_id;
                
                v_candidati_count := v_candidati_count + 1;
                
                -- Se score >= soglia_certo, crea automaticamente il cluster
                IF v_score_totale >= v_soglia_certo THEN
                    DECLARE
                        v_cluster_result RECORD;
                    BEGIN
                        -- Crea cluster automaticamente
                        SELECT * INTO v_cluster_result 
                        FROM sp_crea_cluster_da_candidato(v_candidato_id, 'sistema_automatico');
                        
                        -- Log del risultato (opzionale)
                        IF v_cluster_result.out_result_code = 0 THEN
                            -- Cluster creato con successo
                            NULL; -- Continua normalmente
                        END IF;
                    EXCEPTION 
                        WHEN OTHERS THEN
                            -- Se creazione cluster fallisce, continua comunque
                            NULL;
                    END;
                END IF;
            END IF;
        END IF;
    END LOOP;
    
    -- ========================================
    -- RETURN RISULTATI
    -- ========================================
    
    candidati_trovati := v_candidati_count;
    result_code := 0;
    result_message := CASE 
        WHEN v_candidati_count = 0 THEN 'SUCCESS: Nessun duplicato rilevato'
        ELSE CONCAT('SUCCESS: Rilevati ', v_candidati_count, ' candidati duplicati per review')
    END;
    
    RETURN NEXT;
    
EXCEPTION
    WHEN OTHERS THEN
        candidati_trovati := 0;
        result_code := 9999;
        result_message := CONCAT('ERRORE SCAN DUPLICATI: ', SQLERRM);
        RETURN NEXT;
END;
$$;

-- ========================================
-- FUNZIONE WORKER BATCH PROCESSING
-- ========================================

DROP FUNCTION IF EXISTS sp_process_duplicate_scan_batch(INTEGER) CASCADE;

CREATE OR REPLACE FUNCTION sp_process_duplicate_scan_batch(
    p_batch_size INTEGER DEFAULT 20
)
RETURNS TABLE(
    elaborati INTEGER,
    successi INTEGER,
    errori INTEGER,
    result_code INTEGER,
    result_message VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_elaborati INTEGER := 0;
    v_successi INTEGER := 0;
    v_errori INTEGER := 0;
    v_queue_item RECORD;
    v_scan_result RECORD;
    
BEGIN
    -- ========================================
    -- ELABORAZIONE BATCH CODA
    -- ========================================
    
    FOR v_queue_item IN
        SELECT id, id_paziente, creato_da, tentativi
        FROM duplicate_scan_queue
        WHERE stato IN ('PENDING', 'RETRY')
          AND tentativi < max_tentativi
        ORDER BY 
            CASE priorita 
                WHEN 'ALTA' THEN 1 
                WHEN 'NORMALE' THEN 2 
                WHEN 'BASSA' THEN 3 
            END,
            data_creazione
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    LOOP
        v_elaborati := v_elaborati + 1;
        
        BEGIN
            -- Marca come in elaborazione
            UPDATE duplicate_scan_queue 
            SET stato = 'PROCESSING'::scan_stato_type, 
                data_elaborazione = NOW(),
                tentativi = tentativi + 1
            WHERE id = v_queue_item.id;
            
            -- Esegui scan duplicati
            SELECT * INTO v_scan_result 
            FROM sp_scan_duplicati_post_insert(v_queue_item.id_paziente);
            
            IF v_scan_result.result_code = 0 THEN
                -- Successo
                UPDATE duplicate_scan_queue 
                SET stato = 'COMPLETED'::scan_stato_type,
                    ultimo_errore = NULL,
                    parametri_scan = jsonb_build_object(
                        'candidati_trovati', v_scan_result.candidati_trovati,
                        'elaborazione_completata', NOW()
                    )
                WHERE id = v_queue_item.id;
                
                v_successi := v_successi + 1;
            ELSE
                -- Errore dal scan
                UPDATE duplicate_scan_queue 
                SET stato = CASE 
                    WHEN tentativi >= max_tentativi THEN 'ERROR'::scan_stato_type
                    ELSE 'RETRY'::scan_stato_type
                END,
                ultimo_errore = v_scan_result.result_message
                WHERE id = v_queue_item.id;
                
                v_errori := v_errori + 1;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            -- Errore durante elaborazione
            UPDATE duplicate_scan_queue 
            SET stato = CASE 
                WHEN v_queue_item.tentativi + 1 >= max_tentativi THEN 'ERROR'::scan_stato_type
                ELSE 'RETRY'::scan_stato_type
            END,
            ultimo_errore = CONCAT('EXCEPTION: ', SQLERRM)
            WHERE id = v_queue_item.id;
            
            v_errori := v_errori + 1;
        END;
    END LOOP;
    
    -- ========================================
    -- RETURN STATISTICHE
    -- ========================================
    
    elaborati := v_elaborati;
    successi := v_successi;
    errori := v_errori;
    result_code := 0;
    result_message := CONCAT('Batch elaborato: ', v_elaborati, ' items (', v_successi, ' ok, ', v_errori, ' errori)');
    
    RETURN NEXT;
    
EXCEPTION
    WHEN OTHERS THEN
        elaborati := v_elaborati;
        successi := v_successi;
        errori := v_errori;
        result_code := 9999;
        result_message := CONCAT('ERRORE BATCH: ', SQLERRM);
        RETURN NEXT;
END;
$$;

-- ========================================
-- FUNZIONE UTILITÀ PULIZIA CODA
-- ========================================

DROP FUNCTION IF EXISTS sp_cleanup_duplicate_scan_queue(INTEGER) CASCADE;

CREATE OR REPLACE FUNCTION sp_cleanup_duplicate_scan_queue(
    p_giorni_retention INTEGER DEFAULT 30
)
RETURNS TABLE(
    records_eliminati INTEGER,
    result_code INTEGER,
    result_message VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_eliminati INTEGER;
BEGIN
    -- Elimina record completati più vecchi di X giorni
    DELETE FROM duplicate_scan_queue 
    WHERE stato = 'COMPLETED' 
      AND data_elaborazione < (NOW() - INTERVAL '1 day' * p_giorni_retention);
    
    GET DIAGNOSTICS v_eliminati = ROW_COUNT;
    
    records_eliminati := v_eliminati;
    result_code := 0;
    result_message := CONCAT('Pulizia completata: eliminati ', v_eliminati, ' record obsoleti');
    
    RETURN NEXT;
END;
$$;

-- ========================================
-- FUNZIONE CREAZIONE CLUSTER DA DUPLICATI
-- ========================================

DROP FUNCTION IF EXISTS sp_crea_cluster_da_candidato(BIGINT, VARCHAR(128)) CASCADE;

CREATE OR REPLACE FUNCTION sp_crea_cluster_da_candidato(
    p_id_candidato_duplicato BIGINT,
    p_creato_da VARCHAR(128)
)
RETURNS TABLE(
    out_cluster_id BIGINT,
    out_cluster_uuid UUID,
    out_id_master BIGINT,
    out_membri_aggiunti INTEGER,
    out_result_code INTEGER,
    out_result_message VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id_primario BIGINT;
    v_id_candidato BIGINT;
    v_score DECIMAL(5,2);
    v_cluster_id BIGINT;
    v_cluster_uuid UUID;
    v_completezza_primario INTEGER;
    v_completezza_candidato INTEGER;
    v_id_master BIGINT;
    v_nome_cluster VARCHAR(255);
    v_membri_count INTEGER := 0;
    
BEGIN
    -- ========================================
    -- VERIFICA E RECUPERA CANDIDATO DUPLICATO
    -- ========================================
    
    SELECT cd.id_paziente_primario, cd.id_paziente_candidato, cd.score_matching
    INTO v_id_primario, v_id_candidato, v_score
    FROM candidati_duplicati cd
    WHERE cd.id = p_id_candidato_duplicato 
      AND cd.stato = 'CONFERMATO';
    
    IF NOT FOUND THEN
        out_cluster_id := NULL;
        out_cluster_uuid := NULL;
        out_id_master := NULL;
        out_membri_aggiunti := 0;
        out_result_code := 2001;
        out_result_message := 'ERRORE: Candidato duplicato non trovato o non confermato';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- ========================================
    -- DETERMINA MASTER (PIÙ COMPLETO)
    -- ========================================
    
    -- Calcola completezza paziente primario
    SELECT 
        COALESCE(LENGTH(ap.nome), 0) + COALESCE(LENGTH(ap.secondo_nome), 0) + 
        CASE WHEN ap.data_nascita IS NOT NULL THEN 10 ELSE 0 END +
        CASE WHEN ds.codice_fiscale_hash IS NOT NULL THEN 15 ELSE 0 END +
        COALESCE(LENGTH(dcr.indirizzo_residenza), 0) + 
        COALESCE(LENGTH(dcr.cellulare), 0) +
        COALESCE(LENGTH(dcr.email), 0) +
        CASE WHEN dcr.numero_documento IS NOT NULL THEN 5 ELSE 0 END
    INTO v_completezza_primario
    FROM anagrafiche_pazienti ap
    LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
    LEFT JOIN dati_contatto_residenza dcr ON ap.id = dcr.id_paziente AND dcr.attivo = TRUE
    WHERE ap.id = v_id_primario;
    
    -- Calcola completezza paziente candidato
    SELECT 
        COALESCE(LENGTH(ap.nome), 0) + COALESCE(LENGTH(ap.secondo_nome), 0) + 
        CASE WHEN ap.data_nascita IS NOT NULL THEN 10 ELSE 0 END +
        CASE WHEN ds.codice_fiscale_hash IS NOT NULL THEN 15 ELSE 0 END +
        COALESCE(LENGTH(dcr.indirizzo_residenza), 0) + 
        COALESCE(LENGTH(dcr.cellulare), 0) +
        COALESCE(LENGTH(dcr.email), 0) +
        CASE WHEN dcr.numero_documento IS NOT NULL THEN 5 ELSE 0 END
    INTO v_completezza_candidato
    FROM anagrafiche_pazienti ap
    LEFT JOIN dati_sensibili_pazienti ds ON ap.id = ds.id_paziente
    LEFT JOIN dati_contatto_residenza dcr ON ap.id = dcr.id_paziente AND dcr.attivo = TRUE
    WHERE ap.id = v_id_candidato;
    
    -- Determina master (più completo, a parità il più vecchio)
    IF v_completezza_primario > v_completezza_candidato THEN
        v_id_master := v_id_primario;
    ELSIF v_completezza_candidato > v_completezza_primario THEN
        v_id_master := v_id_candidato;
    ELSE
        -- A parità di completezza, scegli il più vecchio (ID minore)
        v_id_master := LEAST(v_id_primario, v_id_candidato);
    END IF;
    
    -- ========================================
    -- VERIFICA SE GIÀ IN CLUSTER
    -- ========================================
    
    -- Verifica se uno dei due pazienti è già in un cluster attivo
    SELECT ca.id, ca.cluster_uuid
    INTO v_cluster_id, v_cluster_uuid
    FROM cluster_anagrafici ca
    JOIN cluster_membri cm ON ca.id = cm.id_cluster
    WHERE ca.attivo = TRUE
      AND cm.id_anagrafica IN (v_id_primario, v_id_candidato)
    LIMIT 1;
    
    IF v_cluster_id IS NOT NULL THEN
        -- Aggiungi l'altro paziente al cluster esistente
        INSERT INTO cluster_membri (id_cluster, id_anagrafica, is_master, ordinamento, inserito_da)
        SELECT 
            v_cluster_id,
            CASE WHEN cm_existing.id_anagrafica = v_id_primario THEN v_id_candidato ELSE v_id_primario END,
            FALSE,
            COALESCE(MAX(cm_all.ordinamento), 0) + 1,
            p_creato_da
        FROM cluster_membri cm_existing
        JOIN cluster_membri cm_all ON cm_existing.id_cluster = cm_all.id_cluster
        WHERE cm_existing.id_cluster = v_cluster_id
          AND cm_existing.id_anagrafica IN (v_id_primario, v_id_candidato)
        GROUP BY cm_existing.id_anagrafica
        ON CONFLICT (id_cluster, id_anagrafica) DO NOTHING;
        
        GET DIAGNOSTICS v_membri_count = ROW_COUNT;
        v_membri_count := v_membri_count + 1; -- Conta anche il membro esistente
        
    ELSE
        -- ========================================
        -- CREA NUOVO CLUSTER
        -- ========================================
        
        -- Genera nome cluster
        SELECT 
            CONCAT(
                COALESCE(ap.nome, ''), ' ', 
                COALESCE(ap.secondo_nome, ''), 
                ' - Cluster (Score: ', v_score::TEXT, '%)'
            )
        INTO v_nome_cluster
        FROM anagrafiche_pazienti ap
        WHERE ap.id = v_id_master;
        
        -- Crea cluster
        INSERT INTO cluster_anagrafici (
            id_anagrafica_master, 
            nome_cluster, 
            confidence_score, 
            creato_da,
            note
        ) VALUES (
            v_id_master,
            v_nome_cluster,
            v_score,
            p_creato_da,
            CONCAT('Cluster creato da candidato duplicato ID: ', p_id_candidato_duplicato)
        )
        RETURNING id, cluster_uuid INTO v_cluster_id, v_cluster_uuid;
        
        -- Aggiungi master al cluster
        INSERT INTO cluster_membri (id_cluster, id_anagrafica, is_master, ordinamento, inserito_da)
        VALUES (v_cluster_id, v_id_master, TRUE, 0, p_creato_da);
        
        -- Aggiungi l'altro paziente al cluster
        INSERT INTO cluster_membri (id_cluster, id_anagrafica, is_master, ordinamento, inserito_da)
        VALUES (v_cluster_id, 
                CASE WHEN v_id_master = v_id_primario THEN v_id_candidato ELSE v_id_primario END,
                FALSE, 1, p_creato_da);
        
        v_membri_count := 2;
    END IF;
    
    -- ========================================
    -- AGGIORNA CANDIDATO DUPLICATO
    -- ========================================
    
    UPDATE candidati_duplicati 
    SET stato = 'MERGIATO',
        note_revisore = CONCAT(
            COALESCE(note_revisore, ''), 
            ' - Cluster creato ID: ', v_cluster_id
        ),
        data_modifica = NOW()
    WHERE id = p_id_candidato_duplicato;
    
    -- ========================================
    -- RETURN RISULTATI
    -- ========================================
    
    out_cluster_id := v_cluster_id;
    out_cluster_uuid := v_cluster_uuid;
    out_id_master := v_id_master;
    out_membri_aggiunti := v_membri_count;
    out_result_code := 0;
    out_result_message := CONCAT(
        'SUCCESS: Cluster ', v_cluster_id, ' creato/aggiornato con ', 
        v_membri_count, ' membri. Master: ', v_id_master
    );
    
    RETURN NEXT;
    
EXCEPTION
    WHEN OTHERS THEN
        out_cluster_id := NULL;
        out_cluster_uuid := NULL;
        out_id_master := NULL;
        out_membri_aggiunti := 0;
        out_result_code := 9999;
        out_result_message := CONCAT('ERRORE CREAZIONE CLUSTER: ', SQLERRM);
        RETURN NEXT;
END;
$$;

-- ========================================
-- ESEMPI DI UTILIZZO
-- ========================================

/*
-- Test scan manuale per paziente
SELECT * FROM sp_scan_duplicati_post_insert(123);

-- Elaborazione batch (worker)
SELECT * FROM sp_process_duplicate_scan_batch(50);

-- Pulizia coda (manutenzione)
SELECT * FROM sp_cleanup_duplicate_scan_queue(7);

-- Creazione cluster da candidato confermato
SELECT * FROM sp_crea_cluster_da_candidato(45, 'dashboard_user');

-- Monitoraggio coda
SELECT 
    stato,
    priorita,
    COUNT(*) as count,
    AVG(tentativi) as tentativi_medi,
    MIN(data_creazione) as piu_vecchio,
    MAX(data_creazione) as piu_recente
FROM duplicate_scan_queue 
GROUP BY stato, priorita
ORDER BY stato, priorita;
*/

-- ========================================
-- TRIGGER AUTOMATICO CREAZIONE CLUSTER
-- ========================================

-- Funzione per gestire auto-creazione cluster quando candidato diventa CONFERMATO
CREATE OR REPLACE FUNCTION trigger_auto_cluster_creation()
RETURNS TRIGGER AS $$
DECLARE
    v_cluster_result RECORD;
BEGIN
    -- Solo se il candidato passa a CONFERMATO e ha score >= 95%
    IF NEW.stato = 'CONFERMATO' AND OLD.stato != 'CONFERMATO' 
       AND NEW.score_matching >= 95.0 THEN
        
        BEGIN
            -- Crea cluster automaticamente
            SELECT * INTO v_cluster_result 
            FROM sp_crea_cluster_da_candidato(NEW.id, 'sistema_automatico_trigger');
            
            -- Log del risultato (opzionale)
            IF v_cluster_result.result_code = 0 THEN
                -- Update note per indicare creazione automatica
                NEW.note_revisore := COALESCE(NEW.note_revisore, '') || 
                    ' [CLUSTER AUTO-CREATO: ID=' || v_cluster_result.out_cluster_id || ']';
            END IF;
            
        EXCEPTION 
            WHEN OTHERS THEN
                -- Se creazione cluster fallisce, continua comunque
                NEW.note_revisore := COALESCE(NEW.note_revisore, '') || 
                    ' [ERRORE AUTO-CLUSTER: ' || SQLERRM || ']';
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crea il trigger
DROP TRIGGER IF EXISTS trg_auto_cluster_creation ON candidati_duplicati;
CREATE TRIGGER trg_auto_cluster_creation
    BEFORE UPDATE ON candidati_duplicati
    FOR EACH ROW
    EXECUTE FUNCTION trigger_auto_cluster_creation();

-- ========================================
-- FUNZIONE BATCH PER CANDIDATI ESISTENTI
-- ========================================

-- Processa tutti i candidati CONFERMATO esistenti che non hanno cluster
CREATE OR REPLACE FUNCTION sp_process_existing_confermato_candidates()
RETURNS TABLE (
    candidato_id BIGINT,
    cluster_created BOOLEAN,
    cluster_id BIGINT,
    result_message TEXT
) AS $$
DECLARE
    v_candidato RECORD;
    v_cluster_result RECORD;
    v_count INTEGER := 0;
BEGIN
    -- Trova tutti i candidati CONFERMATO con score >= 95% che non hanno cluster associati
    FOR v_candidato IN 
        SELECT cd.id, cd.score_matching
        FROM candidati_duplicati cd
        WHERE cd.stato = 'CONFERMATO' 
          AND cd.score_matching >= 95.0
          AND NOT EXISTS (
              SELECT 1 FROM cluster_membri cm 
              WHERE cm.id_paziente IN (cd.id_paziente_primario, cd.id_paziente_candidato)
          )
        ORDER BY cd.score_matching DESC
    LOOP
        BEGIN
            -- Crea cluster per questo candidato
            SELECT * INTO v_cluster_result 
            FROM sp_crea_cluster_da_candidato(v_candidato.id, 'batch_existing_confermato');
            
            v_count := v_count + 1;
            
            -- Restituisci risultato
            candidato_id := v_candidato.id;
            cluster_created := (v_cluster_result.result_code = 0);
            cluster_id := v_cluster_result.out_cluster_id;
            result_message := v_cluster_result.result_message;
            
            RETURN NEXT;
            
        EXCEPTION 
            WHEN OTHERS THEN
                candidato_id := v_candidato.id;
                cluster_created := FALSE;
                cluster_id := NULL;
                result_message := 'ERRORE: ' || SQLERRM;
                RETURN NEXT;
        END;
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;