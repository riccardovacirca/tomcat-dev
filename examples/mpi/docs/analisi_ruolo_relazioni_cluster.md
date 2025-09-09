# RUOLO DETTAGLIATO DELLE RELAZIONI CLUSTER PROPOSTE

---

## **🎯 OBIETTIVO STRATEGICO**

Le nuove relazioni cluster creano un **"livello di correlazione intermedio"** tra:
- **Rilevamento duplicati** (già esistente)
- **Merge fisico** (da implementare)

Permettono di **raggruppare logicamente** record correlati **SENZA modificarli**, mantenendo lo stato di "indecisione informata" fino alla certezza del merge.

---

## **📊 ANATOMIA DELLE RELAZIONI**

### **TABELLA 1: `cluster_anagrafici` - "Il Contenitore"**

```sql
CREATE TABLE cluster_anagrafici (
  id BIGSERIAL PRIMARY KEY,
  cluster_uuid UUID DEFAULT uuid_generate_v4(),
  nome_cluster VARCHAR(128),                    
  tipo_cluster cluster_type_enum,               
  stato_cluster VARCHAR(16) DEFAULT 'ATTIVO',   
  confidence_score DECIMAL(4,2),                
  creato_da VARCHAR(128),
  data_creazione TIMESTAMP DEFAULT NOW(),
  note_cluster TEXT
);
```

#### **Ruolo: "Registry dei Raggruppamenti"**
- **`cluster_uuid`**: Identificatore univoco e stabile del raggruppamento
- **`nome_cluster`**: Etichetta human-readable (es: "Mario Rossi - Varianti", "Famiglia Bianchi")
- **`tipo_cluster`**: Tipologia di correlazione per comportamenti diversi
- **`confidence_score`**: Grado di certezza del raggruppamento (0.0-1.0)
- **`stato_cluster`**: Workflow del raggruppamento (ATTIVO, IN_REVISIONE, CONSOLIDATO, RISOLTO)

#### **Esempi Pratici:**
```sql
-- Cluster per varianti nominative
INSERT INTO cluster_anagrafici VALUES (
  1, uuid_generate_v4(), 'Mario Rossi - Varianti Nominative', 
  'VARIANTI_NOME', 'ATTIVO', 0.85, 'operatore_123', NOW(),
  'Possibili errori di battitura nel nome/cognome'
);

-- Cluster per nucleo familiare  
INSERT INTO cluster_anagrafici VALUES (
  2, uuid_generate_v4(), 'Famiglia Bianchi - Via Roma 15',
  'NUCLEO_FAMILIARE', 'ATTIVO', 0.95, 'operatore_456', NOW(),
  'Stesso indirizzo, nomi correlati, possibili duplicati intrafamiliari'
);
```

---

### **TABELLA 2: `cluster_membri` - "Le Associazioni"**

```sql
CREATE TABLE cluster_membri (
  id BIGSERIAL PRIMARY KEY,
  id_cluster BIGINT REFERENCES cluster_anagrafici(id),
  id_paziente BIGINT REFERENCES anagrafiche_pazienti(id),
  ruolo_cluster VARCHAR(32),                    
  ordinamento INTEGER DEFAULT 0,                
  data_inserimento TIMESTAMP DEFAULT NOW(),
  inserito_da VARCHAR(128),
  note_membro TEXT
);
```

#### **Ruolo: "Mappa delle Appartenenze"**
- **`id_cluster` + `id_paziente`**: Quale paziente appartiene a quale cluster
- **`ruolo_cluster`**: Ruolo del paziente nel raggruppamento
- **`ordinamento`**: Priorità/anzianità per ordinamento risultati
- **`data_inserimento`**: Tracciabilità temporale delle associazioni

#### **Ruoli Cluster Possibili:**
```sql
-- Enumeration dei ruoli
CREATE TYPE ruolo_cluster_type AS ENUM (
  'PRIMARIO',      -- Record principale/più completo
  'SECONDARIO',    -- Record correlato con alta probabilità
  'SOSPETTO',      -- Record con correlazione incerta
  'FIGLIO',        -- In contesti familiari
  'GENITORE',      -- In contesti familiari  
  'VARIANTE',      -- Variazione del record primario
  'STORICO'        -- Record più vecchio, possibile fonte
);
```

#### **Esempi Pratici:**
```sql
-- Membri del cluster "Mario Rossi - Varianti"
INSERT INTO cluster_membri VALUES 
(1, 1, 123, 'PRIMARIO', 1, NOW(), 'operatore_123', 'Record più completo e recente'),
(2, 1, 456, 'VARIANTE', 2, NOW(), 'operatore_123', 'Cognome con errore tipografico: "Rosi"'),
(3, 1, 789, 'VARIANTE', 3, NOW(), 'operatore_123', 'Nome abbreviato: "M. Rossi"'),
(4, 1, 321, 'SOSPETTO', 4, NOW(), 'operatore_123', 'Data nascita simile ma città diversa');

-- Membri del cluster "Famiglia Bianchi"  
INSERT INTO cluster_membri VALUES
(5, 2, 111, 'GENITORE', 1, NOW(), 'operatore_456', 'Capofamiglia - Carlo Bianchi'),
(6, 2, 222, 'GENITORE', 2, NOW(), 'operatore_456', 'Coniuge - Maria Bianchi'),
(7, 2, 333, 'FIGLIO', 3, NOW(), 'operatore_456', 'Figlio - Luca Bianchi'),
(8, 2, 444, 'SOSPETTO', 4, NOW(), 'operatore_456', 'Possibile duplicato di Maria');
```

---

## **🔄 MECCANISMI DI FUNZIONAMENTO**

### **SCENARIO 1: Query Singola Anagrafica**

#### **Query Tradizionale:**
```sql
SELECT * FROM anagrafiche_pazienti WHERE id = 123;
-- Risultato: 1 record (Mario Rossi)
```

#### **Query con Cluster:**
```sql
SELECT * FROM get_anagrafica_con_correlazioni('ID', '123', TRUE);
-- Risultato: 4 record ordinati
-- 1. Mario Rossi (PRIMARIO, ord: 1)
-- 2. Mario Rosi (VARIANTE, ord: 2)  
-- 3. M. Rossi (VARIANTE, ord: 3)
-- 4. Mario Rossi (SOSPETTO, ord: 4)
```

#### **Comportamento Intelligente:**
- **Se cluster esiste**: Restituisce tutti i membri ordinati
- **Se cluster non esiste**: Restituisce il singolo record (comportamento classico)
- **Operatore può scegliere**: `include_cluster = FALSE` per comportamento classico

---

### **SCENARIO 2: Workflow Decisionale**

#### **Stato "ATTIVO" - Correlazioni Proposte**
```sql
-- Cluster in fase di valutazione
UPDATE cluster_anagrafici SET stato_cluster = 'ATTIVO' WHERE id = 1;

-- Query restituisce tutti i membri per valutazione
SELECT * FROM v_cluster_membri WHERE cluster_id = 1;
-- Operatore vede: Mario Rossi, Mario Rosi, M. Rossi, Mario Rossi(sospetto)
-- Decisione: Confermare correlazioni? Rimuovere sospetto? Mergeare?
```

#### **Stato "IN_REVISIONE" - Sotto Esame**
```sql
-- Cluster sotto revisione umana
UPDATE cluster_anagrafici SET stato_cluster = 'IN_REVISIONE' WHERE id = 1;

-- Possibili azioni:
-- 1. Rimuovere membri incerti
DELETE FROM cluster_membri WHERE id_cluster = 1 AND ruolo_cluster = 'SOSPETTO';

-- 2. Cambiare ruoli
UPDATE cluster_membri SET ruolo_cluster = 'VARIANTE' 
WHERE id_cluster = 1 AND id_paziente = 321;

-- 3. Riordinare priorità  
UPDATE cluster_membri SET ordinamento = 1 WHERE id_paziente = 456; -- Promuovi variante
```

#### **Stato "CONSOLIDATO" - Pronti per Merge**
```sql
-- Cluster validato, pronto per merge fisico
UPDATE cluster_anagrafici SET stato_cluster = 'CONSOLIDATO' WHERE id = 1;

-- Trigger automatici possono:
-- 1. Creare record in candidati_duplicati per coppie cluster
-- 2. Proporre merge automatico del PRIMARIO con SECONDARI
-- 3. Notificare operatori per approvazione finale
```

---

## **🎛️ STRATEGIE DI UTILIZZO**

### **STRATEGIA A: "Correlazione Conservativa"**
- **Cluster piccoli**: 2-3 membri max
- **Alta confidence**: Solo correlazioni > 0.90
- **Ruoli semplici**: PRIMARIO, SECONDARIO
- **Uso**: Ambiente ad alta precisione (oncologia, cardiologia)

### **STRATEGIA B: "Correlazione Esplorativa"** 
- **Cluster estesi**: 4-8 membri
- **Media confidence**: Correlazioni > 0.70
- **Ruoli dettagliati**: PRIMARIO, VARIANTE, SOSPETTO, STORICO
- **Uso**: Ambiente di integrazione dati (fusioni ospedaliere)

### **STRATEGIA C: "Correlazione Familiare"**
- **Cluster gerarchici**: GENITORE → FIGLIO
- **Confidence variabile**: Basata su indirizzo/contatti
- **Ruoli relazionali**: GENITORE, FIGLIO, CONIUGE
- **Uso**: Pediatria, medicina di famiglia

---

## **🔍 VANTAGGI DELLE RELAZIONI**

### **1. FLESSIBILITÀ DECISIONALE**
```sql
-- Operatore può "navigare" tra correlazioni
SELECT cluster_uuid, nome_cluster, COUNT(*) as membri
FROM cluster_anagrafici ca
JOIN cluster_membri cm ON ca.id = cm.id_cluster  
WHERE ca.stato_cluster = 'ATTIVO'
GROUP BY cluster_uuid, nome_cluster
ORDER BY COUNT(*) DESC;

-- Risultato: Lista cluster ordinata per complessità
-- Operatore può scegliere da dove iniziare
```

### **2. TRACCIABILITÀ COMPLETA**
```sql
-- Storico decisioni su ogni cluster
SELECT 
    c.nome_cluster,
    c.stato_cluster, 
    c.creato_da,
    c.data_creazione,
    array_agg(a.nome ORDER BY cm.ordinamento) as membri_attuali
FROM cluster_anagrafici c
JOIN cluster_membri cm ON c.id = cm.id_cluster
JOIN anagrafiche_pazienti a ON cm.id_paziente = a.id
WHERE c.id = 1
GROUP BY c.id, c.nome_cluster, c.stato_cluster, c.creato_da, c.data_creazione;
```

### **3. REVERSIBILITÀ GARANTITA**
```sql
-- Eliminazione cluster senza perdita dati
DELETE FROM cluster_membri WHERE id_cluster = 1;
DELETE FROM cluster_anagrafici WHERE id = 1;
-- Record originali intatti, correlazioni eliminate
```

### **4. SCALABILITÀ CONTROLLATA**
```sql
-- Statistiche per governance
SELECT 
    tipo_cluster,
    stato_cluster,
    COUNT(*) as numero_cluster,
    AVG(confidence_score) as confidence_media,
    SUM(CASE WHEN stato_cluster = 'CONSOLIDATO' THEN 1 ELSE 0 END) as pronti_merge
FROM cluster_anagrafici
GROUP BY tipo_cluster, stato_cluster;
```

---

## **🎯 CONCLUSIONE**

**Le relazioni cluster creano un "layer di intelligenza"** che:

1. **Preserva l'incertezza**: Mantiene correlazioni senza commit definitivi
2. **Guida le decisioni**: Ordina e categorizza le opzioni
3. **Facilita il workflow**: Stati e ruoli per processi strutturati  
4. **Garantisce controllo**: Operatore sempre al centro delle decisioni
5. **Assicura reversibilità**: Nessuna perdita di dati o opzioni

**È un sistema di "merge staging"** che trasforma l'incertezza in un vantaggio operativo.