# PROCEDURA DI MERGE ANAGRAFICHE SANITARIE
## Modello di Implementazione Step-by-Step

Basato sull'architettura esistente nel sistema MPI, propongo la seguente sequenza di stored procedures per implementare il merge completo delle anagrafiche.

---

## **STEP 1: VALIDAZIONE PRE-MERGE**
### `sp_validate_merge_eligibility(p_id_candidato_duplicato BIGINT)`

**Descrizione**: Valida se un candidato duplicato è eligibile per il merge  
**Input**: ID del record in `candidati_duplicati`  
**Output**: Risultato validazione, lista conflitti, raccomandazioni  

**Controlli eseguiti**:
- Verifica stato candidato = 'CONFERMATO' o 'APPROVATO'
- Controllo blacklist merge (evita merge inappropriati)
- Validazione integrità dati (campi obbligatori)
- Identificazione conflitti sui campi critici
- Verifica consensi privacy attivi
- Controllo presenza di prestazioni sanitarie attive

**Logica**:
```sql
-- Pseudo-codice
IF candidato.stato NOT IN ('CONFERMATO', 'APPROVATO') THEN
    RETURN error('Candidato non approvato per merge')
END IF

IF EXISTS blacklist WHERE (id1, id2) THEN
    RETURN error('Merge bloccato da blacklist')
END IF

-- Identifica conflitti campo per campo
FOR campo IN (nome, cognome, data_nascita, codice_fiscale, etc.) DO
    IF master.campo != duplicato.campo AND both NOT NULL THEN
        INSERT INTO conflitti_temporanei...
    END IF
END FOR
```

---

## **STEP 2: RISOLUZIONE CONFLITTI AUTOMATICA**
### `sp_resolve_merge_conflicts(p_id_operazione_merge BIGINT, p_strategia VARCHAR)`

**Descrizione**: Risolve automaticamente i conflitti secondo strategie predefinite  
**Input**: ID operazione merge, strategia globale  
**Output**: Conflitti risolti, conflitti rimasti per revisione manuale  

**Strategie disponibili**:
- `PIU_RECENTE`: Mantiene il valore più recente (basato su data_modifica)
- `PIU_COMPLETO`: Mantiene il valore più completo (non NULL, più lungo)
- `MANTIENI_MASTER`: Priorità sempre al record master
- `CONCATENA`: Per campi testo non critici (note, indirizzi secondari)

**Logica**:
```sql
FOR conflitto IN conflitti_merge WHERE id_operazione = p_id_operazione DO
    CASE p_strategia
        WHEN 'PIU_RECENTE' THEN
            UPDATE SET valore_finale = CASE 
                WHEN master.data_modifica > duplicato.data_modifica 
                THEN master.valore ELSE duplicato.valore END
        WHEN 'PIU_COMPLETO' THEN
            UPDATE SET valore_finale = CASE
                WHEN LENGTH(master.valore) > LENGTH(duplicato.valore)
                THEN master.valore ELSE duplicato.valore END
    END CASE
END FOR
```

---

## **STEP 3: CREAZIONE SNAPSHOT PRE-MERGE**
### `sp_create_merge_snapshot(p_id_master BIGINT, p_id_duplicato BIGINT)`

**Descrizione**: Crea snapshot completo dei dati prima del merge per reversibilità  
**Input**: ID master, ID duplicato  
**Output**: ID snapshot, dati serializzati  

**Dati salvati**:
- Anagrafica completa (anagrafiche_pazienti)
- Dati sensibili (dati_sensibili_pazienti)
- Contatti e residenze (dati_contatto_residenza)
- Relazioni familiari esistenti
- Log audit delle modifiche precedenti

**Logica**:
```sql
-- Serializza dati master
snapshot_master := (
    SELECT row_to_json(ap.*) FROM anagrafiche_pazienti ap WHERE id = p_id_master
) || (
    SELECT row_to_json(ds.*) FROM dati_sensibili_pazienti ds WHERE id_paziente = p_id_master
) || (
    SELECT json_agg(dcr.*) FROM dati_contatto_residenza dcr WHERE id_paziente = p_id_master
);

-- Serializza dati duplicato
snapshot_duplicato := [stessa logica per duplicato];

INSERT INTO operazioni_merge (dati_prima_merge, ...)
VALUES (snapshot_master || snapshot_duplicato, ...);
```

---

## **STEP 4: CONSOLIDAMENTO DATI**
### `sp_consolidate_patient_data(p_id_operazione_merge BIGINT)`

**Descrizione**: Consolida fisicamente i dati dal duplicato al master  
**Input**: ID operazione merge  
**Output**: Record consolidato, summary modifiche  

**Operazioni**:
- Aggiorna campi master con valori risolti dai conflitti
- Migra dati correlati (contatti, residenze, consensi)
- Mantiene storico versioni per audit
- Aggiorna referenze in tabelle correlate

**Logica**:
```sql
-- Aggiorna anagrafica master con dati consolidati
UPDATE anagrafiche_pazienti SET
    nome = COALESCE(conflitti.nome_risolto, nome),
    cognome_hash = COALESCE(conflitti.cognome_risolto, cognome_hash),
    -- ... altri campi
    versione = versione + 1,
    data_modifica = NOW(),
    modificato_da = operazione.eseguito_da
WHERE id = operazione.id_paziente_master;

-- Migra contatti mantenendo priorità
INSERT INTO dati_contatto_residenza (id_paziente, tipo_contatto, valore, priorita)
SELECT p_id_master, tipo_contatto, valore, priorita + 100
FROM dati_contatto_residenza 
WHERE id_paziente = operazione.id_paziente_duplicato
ON CONFLICT (id_paziente, tipo_contatto, valore) DO NOTHING;
```

---

## **STEP 5: AGGIORNAMENTO STATO DUPLICATO**
### `sp_mark_record_as_merged(p_id_duplicato BIGINT, p_id_master BIGINT)`

**Descrizione**: Marca il record duplicato come mergiato e crea il collegamento  
**Input**: ID duplicato, ID master  
**Output**: Stato aggiornato, audit trail  

**Operazioni**:
- Cambia stato_merge a 'MERGIATO'
- Imposta merge_master_id al record master
- Preserva record per audit (non cancella)
- Disattiva logicamente il record (attivo = FALSE)

**Logica**:
```sql
UPDATE anagrafiche_pazienti SET
    stato_merge = 'MERGIATO',
    merge_master_id = p_id_master,
    data_merge = NOW(),
    merge_score = (SELECT score_matching FROM candidati_duplicati 
                   WHERE id_paziente_candidato = p_id_duplicato 
                   ORDER BY data_creazione DESC LIMIT 1),
    attivo = FALSE,
    versione = versione + 1
WHERE id = p_id_duplicato;
```

---

## **STEP 6: FINALIZZAZIONE E AUDIT**
### `sp_finalize_merge_operation(p_id_operazione_merge BIGINT)`

**Descrizione**: Finalizza l'operazione di merge e completa l'audit trail  
**Input**: ID operazione merge  
**Output**: Operazione completata, log finale  

**Operazioni**:
- Aggiorna stato operazione_merge a 'COMPLETATO'
- Marca candidato_duplicati come 'MERGIATO'
- Inserisce log audit dettagliato
- Notifica sistemi esterni (se configurato)
- Valida integrità post-merge

**Logica**:
```sql
-- Finalizza operazione
UPDATE operazioni_merge SET
    id_stato_merge = (SELECT id FROM stati_merge WHERE codice = 'COMPLETATO'),
    data_esecuzione = NOW(),
    reversibile = TRUE
WHERE id = p_id_operazione_merge;

-- Aggiorna candidato
UPDATE candidati_duplicati SET
    stato = 'MERGIATO',
    data_modifica = NOW()
WHERE id = operazione.id_candidato_duplicato;

-- Log audit finale
INSERT INTO log_audit_anagrafiche (operazione, dettagli, ...)
VALUES ('MERGE_COMPLETED', json_build_object(...), ...);
```

---

## **STEP 7: PROCEDURA ORCHESTRATRICE**
### `sp_execute_patient_merge(p_id_candidato_duplicato BIGINT, p_strategia_conflitti VARCHAR, p_eseguito_da VARCHAR)`

**Descrizione**: Procedura principale che orchestra tutti gli step del merge  
**Input**: ID candidato, strategia, operatore  
**Output**: Risultato completo dell'operazione  

**Flusso completo**:
```sql
BEGIN TRANSACTION;
    -- Step 1: Validazione
    PERFORM sp_validate_merge_eligibility(p_id_candidato_duplicato);
    
    -- Step 2: Crea operazione merge
    INSERT INTO operazioni_merge (...) RETURNING id INTO v_operazione_id;
    
    -- Step 3: Snapshot
    PERFORM sp_create_merge_snapshot(v_id_master, v_id_duplicato);
    
    -- Step 4: Risolvi conflitti
    PERFORM sp_resolve_merge_conflicts(v_operazione_id, p_strategia_conflitti);
    
    -- Step 5: Consolida dati
    PERFORM sp_consolidate_patient_data(v_operazione_id);
    
    -- Step 6: Marca duplicato
    PERFORM sp_mark_record_as_merged(v_id_duplicato, v_id_master);
    
    -- Step 7: Finalizza
    PERFORM sp_finalize_merge_operation(v_operazione_id);
    
COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        -- Log errore e cleanup
END;
```

---

## **CONSIDERAZIONI TECNICHE**

### **Transazionalità**
- Ogni merge è una transazione atomica
- Rollback completo in caso di errore
- Lock ottimistici per prevenire modifiche concorrenti

### **Performance**
- Indici su merge_master_id, stato_merge
- Batch processing per merge multipli
- Cleanup periodico dei snapshot vecchi

### **Sicurezza**
- Autorizzazione basata su ruoli
- Audit completo di ogni operazione
- Crittografia per dati sensibili negli snapshot

### **Reversibilità**
- Procedura `sp_reverse_merge()` per annullare merge
- Ripristino da snapshot con validazione
- Mantenimento integrità referenziale