# ANALISI CORRELAZIONI MERGE SENZA MODIFICHE DATI
## Valutazione meccanismi di raggruppamento logico esistenti

---

## **🔍 STATO ATTUALE DELL'ARCHITETTURA**

### **✅ MECCANISMI GIÀ PRESENTI**

#### **1. Tabella `candidati_duplicati` - Correlazioni Identificate**
```sql
CREATE TABLE candidati_duplicati (
  id_paziente_primario BIGINT NOT NULL,    -- Paziente esistente
  id_paziente_candidato BIGINT NOT NULL,   -- Potenziale duplicato
  score_matching DECIMAL(5,2),             -- Grado di correlazione
  stato stato_candidato_type,              -- NUOVO, IN_REVIEW, CONFERMATO
  priorita priorita_type                   -- ALTA, MEDIA, BASSA
);
```

**Questo sistema GIÀ implementa correlazioni senza modifiche:**
- ✅ **Mantiene record originali intatti**
- ✅ **Traccia relazioni tramite ID primario/candidato**
- ✅ **Scoring quantificato per prioritizzazione**
- ✅ **Stati per workflow decisionale**

#### **2. Campo `merge_master_id` - Correlazioni Post-Merge**
```sql
-- In anagrafiche_pazienti
merge_master_id BIGINT DEFAULT NULL,  -- ID record master dopo merge
stato_merge stato_merge_type DEFAULT 'ATTIVO'
```

**Utilizzabile per correlazioni pre-merge:**
- ⚠️ **Attualmente solo post-merge**
- 💡 **Potenzialmente estendibile per raggruppamenti logici**

---

## **🎯 STRATEGIA PROPOSTA: "CLUSTER LOGICI"**

### **OPZIONE A: Estensione Architettura Esistente** ⭐ *RACCOMANDATO*

#### **Nuova Tabella: `cluster_anagrafici`**
```sql
CREATE TABLE cluster_anagrafici (
  id BIGSERIAL PRIMARY KEY,
  cluster_uuid UUID NOT NULL DEFAULT uuid_generate_v4(),
  nome_cluster VARCHAR(128),                    -- Es: "Famiglia Rossi", "Mario R. variants"
  tipo_cluster cluster_type_enum,               -- FAMIGLIA, VARIANTI_NOME, DUPLICATI_SOSPETTI
  stato_cluster VARCHAR(16) DEFAULT 'ATTIVO',   -- ATTIVO, CONSOLIDATO, RISOLTO
  confidence_score DECIMAL(4,2),                -- Affidabilità del raggruppamento
  creato_da VARCHAR(128),
  data_creazione TIMESTAMP DEFAULT NOW(),
  note_cluster TEXT
);

CREATE TABLE cluster_membri (
  id BIGSERIAL PRIMARY KEY,
  id_cluster BIGINT REFERENCES cluster_anagrafici(id),
  id_paziente BIGINT REFERENCES anagrafiche_pazienti(id),
  ruolo_cluster VARCHAR(32),                    -- PRIMARIO, SECONDARIO, SOSPETTO
  ordinamento INTEGER DEFAULT 0,                -- Per ordinamento per anzianità
  data_inserimento TIMESTAMP DEFAULT NOW(),
  inserito_da VARCHAR(128)
);
```

#### **Vista Unificata per Query**
```sql
CREATE VIEW v_anagrafiche_correlate AS
SELECT 
    a.id,
    a.uid,
    a.nome,
    a.data_nascita,
    -- Informazioni cluster
    c.cluster_uuid,
    c.nome_cluster,
    c.tipo_cluster,
    cm.ruolo_cluster,
    cm.ordinamento,
    -- Conteggio membri cluster
    COUNT(*) OVER (PARTITION BY c.id) as membri_cluster,
    -- Ranking per anzianità
    ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY a.data_creazione ASC) as rank_anzianita
FROM anagrafiche_pazienti a
LEFT JOIN cluster_membri cm ON a.id = cm.id_paziente
LEFT JOIN cluster_anagrafici c ON cm.id_cluster = c.id
WHERE a.attivo = TRUE AND a.stato_merge = 'ATTIVO';
```

### **OPZIONE B: Utilizzo Tabella Esistente** 🔄 *ALTERNATIVO*

#### **Estensione `candidati_duplicati` per Cluster**
```sql
-- Aggiungere campi alla tabella esistente
ALTER TABLE candidati_duplicati ADD COLUMN cluster_id UUID DEFAULT NULL;
ALTER TABLE candidati_duplicati ADD COLUMN cluster_ordinamento INTEGER DEFAULT 0;

-- Vista per raggruppamenti
CREATE VIEW v_cluster_duplicati AS
SELECT 
    cluster_id,
    array_agg(id_paziente_primario ORDER BY data_creazione ASC) as pazienti_cluster,
    array_agg(score_matching ORDER BY score_matching DESC) as scores_cluster,
    COUNT(*) as dimensione_cluster
FROM candidati_duplicati 
WHERE cluster_id IS NOT NULL AND stato IN ('NUOVO', 'IN_REVIEW', 'CONFERMATO')
GROUP BY cluster_id;
```

---

## **🚀 IMPLEMENTAZIONE QUERY RECORDSET UNIFICATI**

### **Funzione per Recupero Anagrafica con Correlazioni**
```sql
CREATE OR REPLACE FUNCTION get_anagrafica_con_correlazioni(
    p_input_type VARCHAR(16),  -- 'ID', 'UUID', 'CF', 'NOME_COGNOME'
    p_input_value TEXT,
    p_include_cluster BOOLEAN DEFAULT TRUE
)
RETURNS TABLE(
    id_paziente BIGINT,
    uid_paziente UUID,
    nome VARCHAR(64),
    cognome TEXT,  -- Decrittografato
    data_nascita DATE,
    cluster_info JSONB,
    correlazione_info JSONB,
    ordinamento_cluster INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_target_patient_id BIGINT;
    v_cluster_id BIGINT;
BEGIN
    -- Step 1: Trova paziente target
    CASE p_input_type
        WHEN 'ID' THEN
            v_target_patient_id := p_input_value::BIGINT;
        WHEN 'UUID' THEN
            SELECT id INTO v_target_patient_id 
            FROM anagrafiche_pazienti 
            WHERE uid = p_input_value::UUID;
        -- Altri casi...
    END CASE;
    
    IF NOT p_include_cluster THEN
        -- Ritorna solo il record singolo
        RETURN QUERY
        SELECT 
            a.id, a.uid, a.nome, 
            decrypt_sensitive_data(ds.cognome_crittografato),
            a.data_nascita,
            NULL::JSONB as cluster_info,
            NULL::JSONB as correlazione_info,
            0 as ordinamento_cluster
        FROM anagrafiche_pazienti a
        LEFT JOIN dati_sensibili_pazienti ds ON a.id = ds.id_paziente
        WHERE a.id = v_target_patient_id;
        RETURN;
    END IF;
    
    -- Step 2: Trova cluster di appartenenza
    SELECT id_cluster INTO v_cluster_id
    FROM cluster_membri cm
    WHERE cm.id_paziente = v_target_patient_id;
    
    -- Step 3: Ritorna tutti i membri del cluster ordinati
    RETURN QUERY
    SELECT 
        a.id,
        a.uid,
        a.nome,
        decrypt_sensitive_data(ds.cognome_crittografato),
        a.data_nascita,
        jsonb_build_object(
            'cluster_uuid', c.cluster_uuid,
            'nome_cluster', c.nome_cluster,
            'tipo_cluster', c.tipo_cluster,
            'confidence_score', c.confidence_score
        ) as cluster_info,
        jsonb_build_object(
            'ruolo_cluster', cm.ruolo_cluster,
            'data_inserimento', cm.data_inserimento,
            'totale_membri', COUNT(*) OVER (PARTITION BY c.id)
        ) as correlazione_info,
        cm.ordinamento
    FROM anagrafiche_pazienti a
    JOIN cluster_membri cm ON a.id = cm.id_paziente
    JOIN cluster_anagrafici c ON cm.id_cluster = c.id
    LEFT JOIN dati_sensibili_pazienti ds ON a.id = ds.id_paziente
    WHERE cm.id_cluster = COALESCE(v_cluster_id, -1)
       OR (v_cluster_id IS NULL AND a.id = v_target_patient_id)  -- Fallback singolo record
    ORDER BY cm.ordinamento ASC, a.data_creazione ASC;
END;
$$;
```

### **Esempi di Utilizzo**
```sql
-- Query standard: restituisce singolo paziente se non correlato, 
-- cluster ordinato se correlato
SELECT * FROM get_anagrafica_con_correlazioni('ID', '123', TRUE);

-- Output esempio:
-- id_paziente | nome | cognome | cluster_info.nome_cluster | ordinamento_cluster
-- 123         | Mario| Rossi   | "Varianti Mario R."        | 1
-- 456         | Mario| Rosi    | "Varianti Mario R."        | 2  
-- 789         | M.   | Rossi   | "Varianti Mario R."        | 3

-- Query senza cluster: comportamento classico
SELECT * FROM get_anagrafica_con_correlazioni('ID', '123', FALSE);
-- Restituisce solo il record ID 123
```

---

## **📊 VANTAGGI DELL'APPROCCIO**

### **🔒 Vantaggi Strategici**
1. **Non-invasività**: Record originali mai modificati
2. **Reversibilità**: Cluster eliminabili senza perdita dati
3. **Gradualità**: Implementabile senza impatti sui sistemi esistenti
4. **Flessibilità**: Gestione di correlazioni multiple (famiglia, duplicati, varianti)

### **⚡ Vantaggi Operativi**
1. **Query trasparenti**: Stessa API, comportamento intelligente
2. **Ordinamento personalizzabile**: Per anzianità, affidabilità, completezza
3. **Tracciabilità**: Chi ha creato ogni correlazione e quando
4. **Workflow controllato**: Stati dei cluster per governance

### **🛡️ Vantaggi di Sicurezza**
1. **Audit completo**: Ogni modifica ai cluster tracciata
2. **Autorizzazioni granulari**: Chi può creare/modificare cluster
3. **Backup semplificato**: Correlazioni separabili dai dati core

---

## **🎯 CONCLUSIONI**

### **FATTIBILITÀ: 100% POSSIBILE** ✅

**L'architettura esistente supporta completamente questa strategia:**
- ✅ **Tabelle candidate** già presenti (`candidati_duplicati`)
- ✅ **Infrastruttura audit** già implementata
- ✅ **Decrittografia** già disponibile per confronti
- ✅ **Indici appropriati** già esistenti

### **RACCOMANDAZIONE IMPLEMENTATIVA**

**Fase 1**: Estendere architettura esistente con tabelle cluster
**Fase 2**: Creare vista unificata e funzione di query intelligente  
**Fase 3**: Integrare negli script esistenti
**Fase 4**: Dashboard per gestione cluster

**Tempo stimato**: 1-2 settimane per implementazione completa
**Impatto sui sistemi esistenti**: Nullo (solo aggiunte)
**Complessità**: Media (utilizza pattern già presenti)