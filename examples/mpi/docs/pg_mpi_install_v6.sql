-- ========================================
-- SCHEMA DATABASE ANAGRAFICHE PAZIENTI v6.0 - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- VERSIONE TRIGGER-FREE CON AUDIT PROGRAMMATICO
-- COMPATIBILITÀ: PostgreSQL 12+
-- ========================================

-- Creazione database
-- CREATE DATABASE anagrafiche 
-- WITH ENCODING 'UTF8' 
-- LC_COLLATE 'it_IT.UTF-8' 
-- LC_CTYPE 'it_IT.UTF-8';

-- \c anagrafiche;

-- Installazione estensioni necessarie
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ========================================
-- TABELLE DI RIFERIMENTO (LOOKUP)
-- ========================================

-- Tabella Codici Genere
-- TIPO INTERAZIONE: Read-Only Lookup
-- TIPO INFORMAZIONE: Codici di riferimento per genere paziente
-- ESEMPIO API: GET /api/v1/lookup/codici-genere
DROP TABLE IF EXISTS codici_genere CASCADE;
CREATE TABLE codici_genere (
  codice CHAR(1) NOT NULL,
  descrizione VARCHAR(32) NOT NULL,
  attivo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (codice)
);

INSERT INTO codici_genere VALUES 
('M', 'Maschio', TRUE),
('F', 'Femmina', TRUE),
('U', 'Non specificato', TRUE),
('A', 'Altro', TRUE)
ON CONFLICT (codice) DO NOTHING;

-- Tabella Tipi Documento Identificativo
-- TIPO INTERAZIONE: Read-Only Lookup con possibile amministrazione
-- TIPO INFORMAZIONE: Catalogo tipi documento per identificazione paziente
-- ESEMPIO API: GET /api/v1/lookup/tipi-documento, POST /api/v1/admin/tipi-documento
DROP TABLE IF EXISTS tipi_documento CASCADE;
CREATE TABLE tipi_documento (
  id SERIAL PRIMARY KEY,
  codice VARCHAR(16) NOT NULL UNIQUE,
  descrizione VARCHAR(64) NOT NULL,
  attivo BOOLEAN NOT NULL DEFAULT TRUE
);

-- Tabella Tipi Relazione Familiare
-- TIPO INTERAZIONE: Read-Only Lookup con gestione relazioni bidirezionali
-- TIPO INFORMAZIONE: Definizione tipi relazione familiare con inverse
-- ESEMPIO API: GET /api/v1/lookup/tipi-relazione
DROP TABLE IF EXISTS tipi_relazione CASCADE;
CREATE TABLE tipi_relazione (
  id SMALLSERIAL PRIMARY KEY,
  codice VARCHAR(16) NOT NULL UNIQUE,
  descrizione VARCHAR(64) NOT NULL,
  descrizione_inversa VARCHAR(64) DEFAULT NULL,
  attivo BOOLEAN NOT NULL DEFAULT TRUE
);

-- ========================================
-- TABELLE DI CONFIGURAZIONE MERGE
-- ========================================

-- Tabella Algoritmi di Matching
-- TIPO INTERAZIONE: Configurazione amministrativa, lettura per elaborazione
-- TIPO INFORMAZIONE: Parametri algoritmi rilevamento duplicati
-- ESEMPIO API: GET /api/v1/config/algoritmi-matching, PUT /api/v1/config/algoritmi-matching/{id}
DROP TABLE IF EXISTS algoritmi_matching CASCADE;
CREATE TABLE algoritmi_matching (
  id SMALLSERIAL PRIMARY KEY,
  nome VARCHAR(64) NOT NULL UNIQUE,
  descrizione TEXT,
  peso_nome DECIMAL(3,2) DEFAULT 0.30, -- Peso matching nome
  peso_cognome DECIMAL(3,2) DEFAULT 0.35, -- Peso matching cognome
  peso_data_nascita DECIMAL(3,2) DEFAULT 0.25, -- Peso matching data nascita
  peso_codice_fiscale DECIMAL(3,2) DEFAULT 0.40, -- Peso matching CF
  peso_luogo_nascita DECIMAL(3,2) DEFAULT 0.15, -- Peso matching luogo
  soglia_duplicato_certo DECIMAL(4,2) DEFAULT 95.00, -- Soglia % duplicato certo
  soglia_duplicato_probabile DECIMAL(4,2) DEFAULT 85.00, -- Soglia % duplicato probabile
  soglia_duplicato_possibile DECIMAL(4,2) DEFAULT 70.00, -- Soglia % duplicato possibile
  attivo BOOLEAN NOT NULL DEFAULT TRUE,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Trigger per aggiornamento automatico data_modifica
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_modifica = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_algoritmi_matching_modtime 
  BEFORE UPDATE ON algoritmi_matching 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Tabella Stati Merge
-- TIPO INTERAZIONE: Read-Only Lookup per workflow merge
-- TIPO INFORMAZIONE: Stati workflow operazioni merge
-- ESEMPIO API: GET /api/v1/lookup/stati-merge
DROP TABLE IF EXISTS stati_merge CASCADE;
CREATE TABLE stati_merge (
  id SMALLSERIAL PRIMARY KEY,
  codice VARCHAR(16) NOT NULL UNIQUE,
  descrizione VARCHAR(64) NOT NULL,
  richiede_approvazione BOOLEAN NOT NULL DEFAULT FALSE,
  reversibile BOOLEAN NOT NULL DEFAULT TRUE,
  attivo BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO stati_merge (codice, descrizione, richiede_approvazione, reversibile) VALUES
('PENDENTE', 'In attesa di elaborazione', FALSE, TRUE),
('RILEVATO', 'Duplicato rilevato automaticamente', FALSE, TRUE),
('IN_REVIEW', 'In revisione manuale', TRUE, TRUE),
('APPROVATO', 'Approvato per merge', TRUE, TRUE),
('COMPLETATO', 'Merge completato', FALSE, TRUE),
('RESPINTO', 'Merge respinto', FALSE, TRUE),
('ANNULLATO', 'Merge annullato', FALSE, TRUE)
ON CONFLICT (codice) DO NOTHING;

-- ========================================
-- TABELLE PRINCIPALI ANAGRAFICHE
-- ========================================

-- Tabella Domini Sanitari Base
-- TIPO INTERAZIONE: CRUD completo, integrazione con sistemi esterni
-- TIPO INFORMAZIONE: Definizione domini/organizzazioni sanitarie
-- ESEMPIO API: GET /api/v1/domini-sanitari, POST /api/v1/domini-sanitari, PUT /api/v1/domini-sanitari/{id}
DROP TABLE IF EXISTS domini_sanitari CASCADE;
CREATE TABLE domini_sanitari (
  id SERIAL PRIMARY KEY,
  uid UUID NOT NULL DEFAULT uuid_generate_v4(),
  codice VARCHAR(32) NOT NULL UNIQUE,
  nome VARCHAR(128) NOT NULL,
  nome_breve VARCHAR(64) DEFAULT NULL,
  data_inizio DATE DEFAULT NULL,
  data_fine DATE DEFAULT NULL,
  attivo BOOLEAN NOT NULL DEFAULT TRUE,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  creato_da VARCHAR(128) DEFAULT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_domini_uid ON domini_sanitari (uid);
CREATE INDEX IF NOT EXISTS idx_domini_attivo ON domini_sanitari (attivo);

CREATE TRIGGER update_domini_sanitari_modtime 
  BEFORE UPDATE ON domini_sanitari 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Tabella Anagrafica Principale Pazienti
-- TIPO INTERAZIONE: CRUD completo, ricerca avanzata, operazioni merge
-- TIPO INFORMAZIONE: Dati anagrafici core pazienti (demographics)
-- ESEMPIO API: POST /api/v1/pazienti, GET /api/v1/pazienti/{uid}, PUT /api/v1/pazienti/{uid}
--              GET /api/v1/pazienti/search?nome=...&cognome=...
--              POST /api/v1/pazienti/{uid}/merge-with/{target-uid}
DROP TABLE IF EXISTS anagrafiche_pazienti CASCADE;

-- Creazione tipo ENUM per stato_merge
CREATE TYPE stato_merge_type AS ENUM ('ATTIVO','DUPLICATO','MERGIATO','ELIMINATO');

CREATE TABLE anagrafiche_pazienti (
  id BIGSERIAL PRIMARY KEY,
  uid UUID NOT NULL DEFAULT uuid_generate_v4(),
  nome VARCHAR(64) DEFAULT NULL,
  secondo_nome VARCHAR(64) DEFAULT NULL,
  data_nascita DATE DEFAULT NULL,
  sesso CHAR(1) NOT NULL DEFAULT 'U',
  citta_nascita VARCHAR(128) DEFAULT NULL,
  codice_istat_nascita VARCHAR(6) DEFAULT NULL,
  provincia_nascita VARCHAR(4) DEFAULT NULL,
  nazione_nascita VARCHAR(3) DEFAULT 'ITA',
  consenso_privacy BOOLEAN NOT NULL DEFAULT FALSE,
  data_consenso_privacy TIMESTAMP NULL DEFAULT NULL,
  data_decesso DATE DEFAULT NULL,
  ora_decesso TIME DEFAULT NULL,
  luogo_decesso VARCHAR(128) DEFAULT NULL,
  -- Gestione merge (gestita programmaticamente)
  merge_master_id BIGINT DEFAULT NULL, -- ID record master dopo merge
  stato_merge stato_merge_type NOT NULL DEFAULT 'ATTIVO',
  data_merge TIMESTAMP NULL DEFAULT NULL,
  merge_score DECIMAL(5,2) DEFAULT NULL, -- Score di matching per ultimo merge
  -- Versioning e metadata
  versione INTEGER NOT NULL DEFAULT 1,
  attivo BOOLEAN NOT NULL DEFAULT TRUE,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  creato_da VARCHAR(128) NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_anagrafiche_uid ON anagrafiche_pazienti (uid);
CREATE INDEX IF NOT EXISTS idx_anagrafiche_data_nascita ON anagrafiche_pazienti (data_nascita);
CREATE INDEX IF NOT EXISTS idx_anagrafiche_sesso ON anagrafiche_pazienti (sesso);
CREATE INDEX IF NOT EXISTS idx_anagrafiche_attivo ON anagrafiche_pazienti (attivo);
CREATE INDEX IF NOT EXISTS idx_anagrafiche_stato_merge ON anagrafiche_pazienti (stato_merge);
CREATE INDEX IF NOT EXISTS idx_anagrafiche_merge_master ON anagrafiche_pazienti (merge_master_id);

ALTER TABLE anagrafiche_pazienti 
  ADD CONSTRAINT fk_anagrafiche_sesso 
  FOREIGN KEY (sesso) REFERENCES codici_genere (codice);

ALTER TABLE anagrafiche_pazienti 
  ADD CONSTRAINT fk_anagrafiche_merge_master 
  FOREIGN KEY (merge_master_id) REFERENCES anagrafiche_pazienti (id) ON DELETE SET NULL;

CREATE TRIGGER update_anagrafiche_pazienti_modtime 
  BEFORE UPDATE ON anagrafiche_pazienti 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Tabella Dati Sensibili
-- TIPO INTERAZIONE: Accesso ristretto, crittografia programmatica
-- TIPO INFORMAZIONE: Dati sensibili crittografati (CF, cognome)
-- ESEMPIO API: POST /api/v1/pazienti/{uid}/dati-sensibili (require special auth)
--              GET /api/v1/pazienti/{uid}/dati-sensibili (decrypt on demand)
DROP TABLE IF EXISTS dati_sensibili_pazienti CASCADE;
CREATE TABLE dati_sensibili_pazienti (
  id_paziente BIGINT NOT NULL PRIMARY KEY,
  codice_fiscale_hash VARCHAR(255) NOT NULL,
  codice_fiscale_crittografato BYTEA DEFAULT NULL,
  cognome_hash VARCHAR(255) DEFAULT NULL,
  cognome_crittografato BYTEA DEFAULT NULL,
  secondo_cognome_hash VARCHAR(255) DEFAULT NULL,
  secondo_cognome_crittografato BYTEA DEFAULT NULL,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_dati_sensibili_cf ON dati_sensibili_pazienti (codice_fiscale_hash);
CREATE INDEX IF NOT EXISTS idx_dati_sensibili_cognome ON dati_sensibili_pazienti (cognome_hash);

ALTER TABLE dati_sensibili_pazienti 
  ADD CONSTRAINT fk_dati_sensibili_paziente 
  FOREIGN KEY (id_paziente) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TRIGGER update_dati_sensibili_pazienti_modtime 
  BEFORE UPDATE ON dati_sensibili_pazienti 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Tabella Dati di Contatto e Residenza
-- TIPO INTERAZIONE: CRUD completo, validazione programmatica
-- TIPO INFORMAZIONE: Contatti e indirizzi paziente
-- ESEMPIO API: PUT /api/v1/pazienti/{uid}/contatti, GET /api/v1/pazienti/{uid}/contatti
--              POST /api/v1/pazienti/{uid}/validate-contacts
DROP TABLE IF EXISTS dati_contatto_residenza CASCADE;
CREATE TABLE dati_contatto_residenza (
  id BIGSERIAL PRIMARY KEY,
  id_paziente BIGINT NOT NULL,
  cellulare VARCHAR(20) DEFAULT NULL,
  telefono VARCHAR(20) DEFAULT NULL,
  email VARCHAR(254) DEFAULT NULL,
  altri_contatti TEXT DEFAULT NULL,
  id_tipo_documento INTEGER DEFAULT NULL,
  numero_documento VARCHAR(64) DEFAULT NULL,
  rilasciato_da VARCHAR(128) DEFAULT NULL,
  data_rilascio DATE DEFAULT NULL,
  data_scadenza DATE DEFAULT NULL,
  nazione_residenza VARCHAR(3) DEFAULT 'ITA',
  provincia_residenza VARCHAR(4) DEFAULT NULL,
  codice_istat_residenza VARCHAR(6) DEFAULT NULL,
  citta_residenza VARCHAR(128) DEFAULT NULL,
  indirizzo_residenza VARCHAR(256) DEFAULT NULL,
  cap_residenza VARCHAR(10) DEFAULT NULL,
  cittadinanza VARCHAR(3) DEFAULT 'ITA',
  nazione_domicilio VARCHAR(3) DEFAULT NULL,
  provincia_domicilio VARCHAR(4) DEFAULT NULL,
  codice_istat_domicilio VARCHAR(6) DEFAULT NULL,
  citta_domicilio VARCHAR(128) DEFAULT NULL,
  indirizzo_domicilio VARCHAR(256) DEFAULT NULL,
  cap_domicilio VARCHAR(10) DEFAULT NULL,
  codice_stp VARCHAR(32) DEFAULT NULL,
  data_scadenza_stp DATE DEFAULT NULL,
  codice_eni VARCHAR(16) DEFAULT NULL,
  data_scadenza_eni DATE DEFAULT NULL,
  versione INTEGER NOT NULL DEFAULT 1,
  attivo BOOLEAN NOT NULL DEFAULT TRUE,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  creato_da VARCHAR(128) NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_dati_contatto_paziente ON dati_contatto_residenza (id_paziente);
CREATE INDEX IF NOT EXISTS idx_dati_contatto_email ON dati_contatto_residenza (email);
CREATE INDEX IF NOT EXISTS idx_dati_contatto_cellulare ON dati_contatto_residenza (cellulare);
CREATE INDEX IF NOT EXISTS idx_dati_contatto_telefono ON dati_contatto_residenza (telefono);
CREATE INDEX IF NOT EXISTS idx_dati_contatto_documento ON dati_contatto_residenza (id_tipo_documento, numero_documento);

ALTER TABLE dati_contatto_residenza 
  ADD CONSTRAINT fk_dati_contatto_paziente 
  FOREIGN KEY (id_paziente) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE dati_contatto_residenza 
  ADD CONSTRAINT fk_dati_contatto_tipo_documento 
  FOREIGN KEY (id_tipo_documento) REFERENCES tipi_documento (id);

-- Validazione email con espressione regolare PostgreSQL
ALTER TABLE dati_contatto_residenza 
  ADD CONSTRAINT chk_dati_contatto_email 
  CHECK (email IS NULL OR email ~* '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

CREATE TRIGGER update_dati_contatto_residenza_modtime 
  BEFORE UPDATE ON dati_contatto_residenza 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Tabella Associazioni Paziente-Dominio
-- TIPO INTERAZIONE: CRUD completo, gestione stati, sync con sistemi esterni
-- TIPO INFORMAZIONE: Associazioni pazienti con domini sanitari
-- ESEMPIO API: POST /api/v1/pazienti/{uid}/associazioni, GET /api/v1/domini/{id}/pazienti
--              PUT /api/v1/associazioni/{id}/stato
DROP TABLE IF EXISTS associazioni_paziente_dominio CASCADE;

CREATE TYPE stato_associazione_type AS ENUM ('ATTIVO','INATTIVO','SOSPESO','UNIFICATO');

CREATE TABLE associazioni_paziente_dominio (
  id BIGSERIAL PRIMARY KEY,
  id_paziente BIGINT NOT NULL,
  id_dominio INTEGER NOT NULL,
  id_esterno VARCHAR(64) NOT NULL,
  codice_esterno VARCHAR(64) DEFAULT NULL,
  data_registrazione DATE DEFAULT NULL,
  data_ultimo_accesso TIMESTAMP NULL DEFAULT NULL,
  stato stato_associazione_type NOT NULL DEFAULT 'ATTIVO',
  versione INTEGER NOT NULL DEFAULT 1,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  creato_da VARCHAR(128) NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_associazioni_esterno ON associazioni_paziente_dominio (id_dominio, id_esterno);
CREATE INDEX IF NOT EXISTS idx_associazioni_paziente ON associazioni_paziente_dominio (id_paziente);
CREATE INDEX IF NOT EXISTS idx_associazioni_stato ON associazioni_paziente_dominio (stato);

ALTER TABLE associazioni_paziente_dominio 
  ADD CONSTRAINT fk_associazioni_paziente 
  FOREIGN KEY (id_paziente) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE associazioni_paziente_dominio 
  ADD CONSTRAINT fk_associazioni_dominio 
  FOREIGN KEY (id_dominio) REFERENCES domini_sanitari (id) ON UPDATE CASCADE;

CREATE TRIGGER update_associazioni_paziente_dominio_modtime 
  BEFORE UPDATE ON associazioni_paziente_dominio 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Tabella Relazioni Familiari
-- TIPO INTERAZIONE: CRUD completo, gestione relazioni bidirezionali
-- TIPO INFORMAZIONE: Relazioni familiari tra pazienti
-- ESEMPIO API: POST /api/v1/pazienti/{uid}/relazioni, GET /api/v1/pazienti/{uid}/famiglia
--              PUT /api/v1/relazioni/{id}/verifica
DROP TABLE IF EXISTS relazioni_familiari CASCADE;
CREATE TABLE relazioni_familiari (
  id BIGSERIAL PRIMARY KEY,
  id_paziente_principale BIGINT NOT NULL,
  id_paziente_correlato BIGINT NOT NULL,
  id_tipo_relazione SMALLINT NOT NULL,
  data_inizio DATE DEFAULT NULL,
  data_fine DATE DEFAULT NULL,
  note TEXT DEFAULT NULL,
  verificata BOOLEAN NOT NULL DEFAULT FALSE,
  data_verifica TIMESTAMP NULL DEFAULT NULL,
  fonte_verifica VARCHAR(128) DEFAULT NULL,
  attivo BOOLEAN NOT NULL DEFAULT TRUE,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  creato_da VARCHAR(128) NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_relazioni_unique ON relazioni_familiari (id_paziente_principale, id_paziente_correlato, id_tipo_relazione);
CREATE INDEX IF NOT EXISTS idx_relazioni_correlato ON relazioni_familiari (id_paziente_correlato);
CREATE INDEX IF NOT EXISTS idx_relazioni_tipo ON relazioni_familiari (id_tipo_relazione);
CREATE INDEX IF NOT EXISTS idx_relazioni_attivo ON relazioni_familiari (attivo);

ALTER TABLE relazioni_familiari 
  ADD CONSTRAINT fk_relazioni_principale 
  FOREIGN KEY (id_paziente_principale) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE relazioni_familiari 
  ADD CONSTRAINT fk_relazioni_correlato 
  FOREIGN KEY (id_paziente_correlato) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE relazioni_familiari 
  ADD CONSTRAINT fk_relazioni_tipo 
  FOREIGN KEY (id_tipo_relazione) REFERENCES tipi_relazione (id);

ALTER TABLE relazioni_familiari 
  ADD CONSTRAINT chk_relazioni_diversi 
  CHECK (id_paziente_principale != id_paziente_correlato);

CREATE TRIGGER update_relazioni_familiari_modtime 
  BEFORE UPDATE ON relazioni_familiari 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- ========================================
-- TABELLE PER GESTIONE DUPLICATI/MERGE
-- ========================================

-- Tabella Candidati Duplicati
-- TIPO INTERAZIONE: Workflow processing, dashboard review
-- TIPO INFORMAZIONE: Candidati duplicati per revisione
-- ESEMPIO API: GET /api/v1/duplicati/candidati, POST /api/v1/duplicati/scan
--              PUT /api/v1/duplicati/{id}/approva, PUT /api/v1/duplicati/{id}/rifiuta
DROP TABLE IF EXISTS candidati_duplicati CASCADE;

CREATE TYPE tipo_rilevamento_type AS ENUM ('AUTOMATICO','MANUALE','IMPORT');
CREATE TYPE stato_candidato_type AS ENUM ('NUOVO','IN_REVIEW','CONFERMATO','RESPINTO','MERGIATO');
CREATE TYPE priorita_type AS ENUM ('ALTA','MEDIA','BASSA');

CREATE TABLE candidati_duplicati (
  id BIGSERIAL PRIMARY KEY,
  id_paziente_primario BIGINT NOT NULL, -- Paziente esistente
  id_paziente_candidato BIGINT NOT NULL, -- Potenziale duplicato
  id_algoritmo SMALLINT NOT NULL,
  score_matching DECIMAL(5,2) NOT NULL, -- Punteggio similarità 0-100
  dettaglio_score TEXT DEFAULT NULL, -- Dettaglio punteggi per campo
  tipo_rilevamento tipo_rilevamento_type NOT NULL DEFAULT 'AUTOMATICO',
  stato stato_candidato_type NOT NULL DEFAULT 'NUOVO',
  priorita priorita_type NOT NULL DEFAULT 'MEDIA',
  note_revisore TEXT DEFAULT NULL,
  revisore VARCHAR(128) DEFAULT NULL,
  data_revisione TIMESTAMP NULL DEFAULT NULL,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_candidati_coppia ON candidati_duplicati (id_paziente_primario, id_paziente_candidato);
CREATE INDEX IF NOT EXISTS idx_candidati_score ON candidati_duplicati (score_matching DESC);
CREATE INDEX IF NOT EXISTS idx_candidati_stato ON candidati_duplicati (stato);
CREATE INDEX IF NOT EXISTS idx_candidati_priorita ON candidati_duplicati (priorita);
CREATE INDEX IF NOT EXISTS idx_candidati_candidato ON candidati_duplicati (id_paziente_candidato);
CREATE INDEX IF NOT EXISTS idx_candidati_algoritmo ON candidati_duplicati (id_algoritmo);

ALTER TABLE candidati_duplicati 
  ADD CONSTRAINT fk_candidati_primario 
  FOREIGN KEY (id_paziente_primario) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE;

ALTER TABLE candidati_duplicati 
  ADD CONSTRAINT fk_candidati_candidato 
  FOREIGN KEY (id_paziente_candidato) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE;

ALTER TABLE candidati_duplicati 
  ADD CONSTRAINT fk_candidati_algoritmo 
  FOREIGN KEY (id_algoritmo) REFERENCES algoritmi_matching (id);

CREATE TRIGGER update_candidati_duplicati_modtime 
  BEFORE UPDATE ON candidati_duplicati 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- ========================================
-- TABELLE CLUSTER ANAGRAFICI
-- ========================================

-- Tabella Cluster Anagrafici
-- TIPO INTERAZIONE: Gestione correlazioni semplificata  
-- TIPO INFORMAZIONE: Raggruppamenti logici di anagrafiche correlate
-- SCOPO: Ogni cluster rappresenta un gruppo di anagrafiche elegibili per merge
--        con una anagrafica master (più completa) che viene presentata per prima
DROP TABLE IF EXISTS cluster_anagrafici CASCADE;

CREATE TABLE cluster_anagrafici (
  id BIGSERIAL PRIMARY KEY,
  cluster_uuid UUID DEFAULT uuid_generate_v4() NOT NULL UNIQUE,
  id_anagrafica_master BIGINT NOT NULL, -- Anagrafica più completa del cluster
  nome_cluster VARCHAR(255) DEFAULT NULL, -- Nome descrittivo opzionale
  attivo BOOLEAN NOT NULL DEFAULT TRUE, -- FALSE dopo merge completato
  confidence_score DECIMAL(5,2) DEFAULT NULL, -- Score medio delle correlazioni
  creato_da VARCHAR(128) NOT NULL,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_modifica TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  note TEXT DEFAULT NULL
);

-- Indici per performance
CREATE INDEX IF NOT EXISTS idx_cluster_master ON cluster_anagrafici (id_anagrafica_master);
CREATE INDEX IF NOT EXISTS idx_cluster_uuid ON cluster_anagrafici (cluster_uuid);
CREATE INDEX IF NOT EXISTS idx_cluster_attivo ON cluster_anagrafici (attivo);

-- Foreign key verso anagrafiche_pazienti
ALTER TABLE cluster_anagrafici 
  ADD CONSTRAINT fk_cluster_master 
  FOREIGN KEY (id_anagrafica_master) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE;

-- Trigger per aggiornamento data modifica
CREATE TRIGGER update_cluster_anagrafici_modtime 
  BEFORE UPDATE ON cluster_anagrafici 
  FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Tabella Membri Cluster
-- TIPO INTERAZIONE: Associazioni anagrafica-cluster
-- TIPO INFORMAZIONE: Quali anagrafiche appartengono a quale cluster
DROP TABLE IF EXISTS cluster_membri CASCADE;

CREATE TABLE cluster_membri (
  id BIGSERIAL PRIMARY KEY,
  id_cluster BIGINT NOT NULL,
  id_anagrafica BIGINT NOT NULL,
  is_master BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE solo per l'anagrafica master
  ordinamento INTEGER NOT NULL DEFAULT 0, -- Ordine di presentazione (master=0)
  data_inserimento TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  inserito_da VARCHAR(128) NOT NULL,
  note TEXT DEFAULT NULL
);

-- Indici per performance e integrità
CREATE UNIQUE INDEX IF NOT EXISTS uk_cluster_anagrafica ON cluster_membri (id_cluster, id_anagrafica);
CREATE INDEX IF NOT EXISTS idx_membri_cluster ON cluster_membri (id_cluster);
CREATE INDEX IF NOT EXISTS idx_membri_anagrafica ON cluster_membri (id_anagrafica);
CREATE INDEX IF NOT EXISTS idx_membri_master ON cluster_membri (is_master);
CREATE INDEX IF NOT EXISTS idx_membri_ordinamento ON cluster_membri (id_cluster, ordinamento);

-- Foreign keys
ALTER TABLE cluster_membri 
  ADD CONSTRAINT fk_membri_cluster 
  FOREIGN KEY (id_cluster) REFERENCES cluster_anagrafici (id) ON DELETE CASCADE;

ALTER TABLE cluster_membri 
  ADD CONSTRAINT fk_membri_anagrafica 
  FOREIGN KEY (id_anagrafica) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE;

-- Constraint: solo un master per cluster
CREATE UNIQUE INDEX IF NOT EXISTS uk_cluster_master_unico 
  ON cluster_membri (id_cluster) 
  WHERE is_master = TRUE;

-- Tabella Operazioni Merge
-- TIPO INTERAZIONE: Storico operazioni, rollback management
-- TIPO INFORMAZIONE: Storico completo operazioni merge
-- ESEMPIO API: GET /api/v1/merge/storico, POST /api/v1/merge/esegui
--              POST /api/v1/merge/{id}/rollback
DROP TABLE IF EXISTS operazioni_merge CASCADE;

CREATE TYPE tipo_merge_type AS ENUM ('AUTOMATICO','SEMIAUTOMATICO','MANUALE');

CREATE TABLE operazioni_merge (
  id BIGSERIAL PRIMARY KEY,
  id_paziente_master BIGINT NOT NULL, -- Record mantenuto
  id_paziente_duplicato BIGINT NOT NULL, -- Record mergiato
  id_candidato_duplicato BIGINT DEFAULT NULL, -- Riferimento candidato se automatico
  id_stato_merge SMALLINT NOT NULL,
  tipo_merge tipo_merge_type NOT NULL,
  score_finale DECIMAL(5,2) DEFAULT NULL,
  strategia_merge TEXT DEFAULT NULL, -- Regole applicate durante merge
  dati_prima_merge TEXT DEFAULT NULL, -- Snapshot dati prima merge
  conflitti_risolti TEXT DEFAULT NULL, -- Conflitti e risoluzioni
  approvato_da VARCHAR(128) DEFAULT NULL,
  data_approvazione TIMESTAMP NULL DEFAULT NULL,
  eseguito_da VARCHAR(128) NOT NULL,
  data_esecuzione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  note TEXT DEFAULT NULL,
  reversibile BOOLEAN NOT NULL DEFAULT TRUE,
  data_rollback TIMESTAMP NULL DEFAULT NULL,
  rollback_da VARCHAR(128) DEFAULT NULL,
  motivo_rollback TEXT DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_merge_master ON operazioni_merge (id_paziente_master);
CREATE INDEX IF NOT EXISTS idx_merge_duplicato ON operazioni_merge (id_paziente_duplicato);
CREATE INDEX IF NOT EXISTS idx_merge_candidato ON operazioni_merge (id_candidato_duplicato);
CREATE INDEX IF NOT EXISTS idx_merge_stato ON operazioni_merge (id_stato_merge);
CREATE INDEX IF NOT EXISTS idx_merge_data ON operazioni_merge (data_esecuzione);
CREATE INDEX IF NOT EXISTS idx_merge_reversibile ON operazioni_merge (reversibile);

ALTER TABLE operazioni_merge 
  ADD CONSTRAINT fk_merge_master 
  FOREIGN KEY (id_paziente_master) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE;

ALTER TABLE operazioni_merge 
  ADD CONSTRAINT fk_merge_duplicato 
  FOREIGN KEY (id_paziente_duplicato) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE;

ALTER TABLE operazioni_merge 
  ADD CONSTRAINT fk_merge_candidato 
  FOREIGN KEY (id_candidato_duplicato) REFERENCES candidati_duplicati (id) ON DELETE SET NULL;

ALTER TABLE operazioni_merge 
  ADD CONSTRAINT fk_merge_stato 
  FOREIGN KEY (id_stato_merge) REFERENCES stati_merge (id);

-- Tabella Conflitti Merge
-- TIPO INTERAZIONE: Risoluzione conflitti, gestione merge complessi
-- TIPO INFORMAZIONE: Conflitti rilevati durante merge
-- ESEMPIO API: GET /api/v1/merge/{id}/conflitti, POST /api/v1/merge/{id}/risolvi-conflitto
DROP TABLE IF EXISTS conflitti_merge CASCADE;

CREATE TYPE strategia_risoluzione_type AS ENUM (
  'MANTIENI_MASTER','MANTIENI_DUPLICATO','MANUALE','CONCATENA','PIU_RECENTE','PIU_COMPLETO'
);

CREATE TABLE conflitti_merge (
  id BIGSERIAL PRIMARY KEY,
  id_operazione_merge BIGINT NOT NULL,
  campo_conflitto VARCHAR(64) NOT NULL, -- Nome campo in conflitto
  valore_master TEXT DEFAULT NULL, -- Valore nel record master
  valore_duplicato TEXT DEFAULT NULL, -- Valore nel record duplicato
  valore_finale TEXT DEFAULT NULL, -- Valore scelto dopo risoluzione
  strategia_risoluzione strategia_risoluzione_type NOT NULL,
  risolto_automaticamente BOOLEAN NOT NULL DEFAULT FALSE,
  risolto_da VARCHAR(128) DEFAULT NULL,
  data_risoluzione TIMESTAMP NULL DEFAULT NULL,
  note_risoluzione TEXT DEFAULT NULL,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_conflitti_merge ON conflitti_merge (id_operazione_merge);
CREATE INDEX IF NOT EXISTS idx_conflitti_campo ON conflitti_merge (campo_conflitto);
CREATE INDEX IF NOT EXISTS idx_conflitti_strategia ON conflitti_merge (strategia_risoluzione);

ALTER TABLE conflitti_merge 
  ADD CONSTRAINT fk_conflitti_merge 
  FOREIGN KEY (id_operazione_merge) REFERENCES operazioni_merge (id) ON DELETE CASCADE;

-- Tabella Blacklist Merge
-- TIPO INTERAZIONE: Gestione eccezioni, amministrazione
-- TIPO INFORMAZIONE: Coppie record da non considerare duplicati
-- ESEMPIO API: POST /api/v1/merge/blacklist, DELETE /api/v1/merge/blacklist/{id}
DROP TABLE IF EXISTS blacklist_merge CASCADE;
CREATE TABLE blacklist_merge (
  id BIGSERIAL PRIMARY KEY,
  id_paziente_1 BIGINT NOT NULL,
  id_paziente_2 BIGINT NOT NULL,
  motivo TEXT NOT NULL,
  inserito_da VARCHAR(128) NOT NULL,
  data_inserimento TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  scadenza TIMESTAMP NULL DEFAULT NULL, -- NULL = permanente
  attivo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_blacklist_coppia ON blacklist_merge (id_paziente_1, id_paziente_2);
CREATE INDEX IF NOT EXISTS idx_blacklist_paziente2 ON blacklist_merge (id_paziente_2);
CREATE INDEX IF NOT EXISTS idx_blacklist_scadenza ON blacklist_merge (scadenza);
CREATE INDEX IF NOT EXISTS idx_blacklist_attivo ON blacklist_merge (attivo);

ALTER TABLE blacklist_merge 
  ADD CONSTRAINT fk_blacklist_paziente1 
  FOREIGN KEY (id_paziente_1) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE;

ALTER TABLE blacklist_merge 
  ADD CONSTRAINT fk_blacklist_paziente2 
  FOREIGN KEY (id_paziente_2) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE;

ALTER TABLE blacklist_merge 
  ADD CONSTRAINT chk_blacklist_diversi 
  CHECK (id_paziente_1 != id_paziente_2);

-- ========================================
-- SISTEMA ASINCRONO RILEVAMENTO DUPLICATI
-- ========================================

-- Tabella Coda Scan Duplicati
-- TIPO INTERAZIONE: Queue processing, background jobs
-- TIPO INFORMAZIONE: Coda elaborazione scan duplicati asincroni
-- ESEMPIO API: Internal queue processing
DROP TABLE IF EXISTS duplicate_scan_queue CASCADE;

CREATE TYPE scan_priorita_type AS ENUM ('ALTA','NORMALE','BASSA');
CREATE TYPE scan_stato_type AS ENUM ('PENDING','PROCESSING','COMPLETED','ERROR','RETRY');

CREATE TABLE duplicate_scan_queue (
  id BIGSERIAL PRIMARY KEY,
  id_paziente BIGINT NOT NULL,
  priorita scan_priorita_type NOT NULL DEFAULT 'NORMALE',
  stato scan_stato_type NOT NULL DEFAULT 'PENDING',
  tentativi INTEGER NOT NULL DEFAULT 0,
  max_tentativi INTEGER NOT NULL DEFAULT 3,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_elaborazione TIMESTAMP NULL DEFAULT NULL,
  ultimo_errore TEXT DEFAULT NULL,
  parametri_scan JSONB DEFAULT NULL, -- Parametri aggiuntivi per scan
  creato_da VARCHAR(128) NOT NULL,
  
  -- Constraint e indici
  CONSTRAINT fk_duplicate_scan_paziente 
    FOREIGN KEY (id_paziente) REFERENCES anagrafiche_pazienti (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_duplicate_scan_stato ON duplicate_scan_queue (stato);
CREATE INDEX IF NOT EXISTS idx_duplicate_scan_priorita ON duplicate_scan_queue (priorita);
CREATE INDEX IF NOT EXISTS idx_duplicate_scan_paziente ON duplicate_scan_queue (id_paziente);
CREATE INDEX IF NOT EXISTS idx_duplicate_scan_elaborazione ON duplicate_scan_queue (data_elaborazione);
CREATE INDEX IF NOT EXISTS idx_duplicate_scan_pending ON duplicate_scan_queue (stato, priorita, data_creazione) 
  WHERE stato = 'PENDING';

-- ========================================
-- SISTEMA DI AUDIT ANAGRAFICO
-- ========================================

-- Tabella Log Audit Anagrafico
-- TIPO INTERAZIONE: Scrittura programmatica, ricerca audit trail
-- TIPO INFORMAZIONE: Log completo operazioni anagrafico
-- ESEMPIO API: GET /api/v1/audit/log?tabella=...&id=..., POST /api/v1/audit/log (internal)
DROP TABLE IF EXISTS log_audit_anagrafico CASCADE;

CREATE TYPE operazione_audit_type AS ENUM ('INSERT','UPDATE','DELETE','RESTORE','MERGE');

CREATE TABLE log_audit_anagrafico (
  id BIGSERIAL,
  nome_tabella VARCHAR(64) NOT NULL,
  id_record BIGINT NOT NULL,
  operazione operazione_audit_type NOT NULL,
  valori_precedenti TEXT DEFAULT NULL,
  valori_nuovi TEXT DEFAULT NULL,
  campi_modificati TEXT DEFAULT NULL,
  id_utente VARCHAR(128) NOT NULL,
  id_sessione VARCHAR(128) DEFAULT NULL,
  indirizzo_ip INET DEFAULT NULL,
  user_agent VARCHAR(512) DEFAULT NULL,
  data_creazione TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id, data_creazione)
) PARTITION BY RANGE (data_creazione);

-- Creazione partizioni per anni (PostgreSQL 10+)
CREATE TABLE log_audit_anagrafico_2023 PARTITION OF log_audit_anagrafico 
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE log_audit_anagrafico_2024 PARTITION OF log_audit_anagrafico 
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE log_audit_anagrafico_2025 PARTITION OF log_audit_anagrafico 
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE log_audit_anagrafico_default PARTITION OF log_audit_anagrafico 
  DEFAULT;

-- Indici per le partizioni
CREATE INDEX IF NOT EXISTS idx_log_audit_tabella_2023 ON log_audit_anagrafico_2023 (nome_tabella, id_record);
CREATE INDEX IF NOT EXISTS idx_log_audit_utente_2023 ON log_audit_anagrafico_2023 (id_utente);

CREATE INDEX IF NOT EXISTS idx_log_audit_tabella_2024 ON log_audit_anagrafico_2024 (nome_tabella, id_record);
CREATE INDEX IF NOT EXISTS idx_log_audit_utente_2024 ON log_audit_anagrafico_2024 (id_utente);

CREATE INDEX IF NOT EXISTS idx_log_audit_tabella_2025 ON log_audit_anagrafico_2025 (nome_tabella, id_record);
CREATE INDEX IF NOT EXISTS idx_log_audit_utente_2025 ON log_audit_anagrafico_2025 (id_utente);

CREATE INDEX IF NOT EXISTS idx_log_audit_tabella_default ON log_audit_anagrafico_default (nome_tabella, id_record);
CREATE INDEX IF NOT EXISTS idx_log_audit_utente_default ON log_audit_anagrafico_default (id_utente);

-- ========================================
-- VISTE PER ACCESSO OTTIMIZZATO
-- ========================================

-- Vista Paziente Anagrafico Completo
DROP VIEW IF EXISTS v_paziente_anagrafico CASCADE;
CREATE VIEW v_paziente_anagrafico AS
SELECT 
  a.id,
  a.uid,
  a.nome,
  a.secondo_nome,
  CASE 
    WHEN a.attivo = TRUE AND a.stato_merge = 'ATTIVO' THEN ds.cognome_crittografato 
    ELSE NULL 
  END as cognome,
  CASE 
    WHEN a.attivo = TRUE AND a.stato_merge = 'ATTIVO' THEN ds.secondo_cognome_crittografato 
    ELSE NULL 
  END as secondo_cognome,
  a.data_nascita,
  a.sesso,
  cg.descrizione as descrizione_sesso,
  a.citta_nascita,
  a.provincia_nascita,
  a.nazione_nascita,
  a.consenso_privacy,
  a.data_consenso_privacy,
  a.data_decesso,
  a.ora_decesso,
  a.luogo_decesso,
  a.stato_merge,
  a.merge_master_id,
  a.data_merge,
  a.merge_score,
  a.attivo,
  dcr.cellulare,
  dcr.telefono,
  dcr.email,
  td.descrizione as tipo_documento,
  dcr.numero_documento,
  dcr.data_scadenza as scadenza_documento,
  dcr.indirizzo_residenza,
  dcr.citta_residenza,
  dcr.provincia_residenza,
  dcr.cap_residenza,
  dcr.cittadinanza,
  dcr.indirizzo_domicilio,
  dcr.citta_domicilio,
  dcr.provincia_domicilio,
  dcr.cap_domicilio,
  a.data_creazione,
  a.data_modifica,
  a.versione
FROM anagrafiche_pazienti a
LEFT JOIN dati_sensibili_pazienti ds ON a.id = ds.id_paziente
LEFT JOIN dati_contatto_residenza dcr ON a.id = dcr.id_paziente
LEFT JOIN codici_genere cg ON a.sesso = cg.codice
LEFT JOIN tipi_documento td ON dcr.id_tipo_documento = td.id
WHERE a.stato_merge = 'ATTIVO';

-- Vista Candidati Duplicati da Revisionare
DROP VIEW IF EXISTS v_candidati_duplicati_review CASCADE;
CREATE VIEW v_candidati_duplicati_review AS
SELECT 
  cd.id,
  cd.id_paziente_primario,
  a1.uid as uid_primario,
  CONCAT(a1.nome, ' ', COALESCE(ds1.cognome_crittografato::text, '')) as nome_completo_primario,
  a1.data_nascita as nascita_primario,
  cd.id_paziente_candidato,
  a2.uid as uid_candidato,
  CONCAT(a2.nome, ' ', COALESCE(ds2.cognome_crittografato::text, '')) as nome_completo_candidato,
  a2.data_nascita as nascita_candidato,
  cd.score_matching,
  cd.dettaglio_score,
  cd.tipo_rilevamento,
  cd.stato,
  cd.priorita,
  am.nome as algoritmo,
  cd.data_creazione,
  DATE_PART('day', NOW() - cd.data_creazione) as giorni_pendenti
FROM candidati_duplicati cd
JOIN anagrafiche_pazienti a1 ON cd.id_paziente_primario = a1.id
JOIN anagrafiche_pazienti a2 ON cd.id_paziente_candidato = a2.id
LEFT JOIN dati_sensibili_pazienti ds1 ON a1.id = ds1.id_paziente
LEFT JOIN dati_sensibili_pazienti ds2 ON a2.id = ds2.id_paziente
JOIN algoritmi_matching am ON cd.id_algoritmo = am.id
WHERE cd.stato IN ('NUOVO', 'IN_REVIEW')
  AND a1.stato_merge = 'ATTIVO'
  AND a2.stato_merge = 'ATTIVO'
ORDER BY cd.priorita, cd.score_matching DESC;

-- Vista Storico Merge
DROP VIEW IF EXISTS v_storico_merge CASCADE;
CREATE VIEW v_storico_merge AS
SELECT 
  om.id,
  om.id_paziente_master,
  a1.uid as uid_master,
  om.id_paziente_duplicato,
  a2.uid as uid_duplicato,
  om.tipo_merge,
  om.score_finale,
  sm.descrizione as stato_merge,
  om.approvato_da,
  om.data_approvazione,
  om.eseguito_da,
  om.data_esecuzione,
  om.reversibile,
  om.data_rollback,
  om.rollback_da,
  CASE 
    WHEN om.data_rollback IS NOT NULL THEN 'ROLLBACK'
    ELSE 'ATTIVO'
  END as stato_operazione
FROM operazioni_merge om
JOIN anagrafiche_pazienti a1 ON om.id_paziente_master = a1.id
JOIN anagrafiche_pazienti a2 ON om.id_paziente_duplicato = a2.id
JOIN stati_merge sm ON om.id_stato_merge = sm.id
ORDER BY om.data_esecuzione DESC;

-- ========================================
-- DATI DI CONFIGURAZIONE
-- ========================================

-- Inserimento algoritmo matching di default
INSERT INTO algoritmi_matching (
  nome, descrizione, peso_nome, peso_cognome, peso_data_nascita, 
  peso_codice_fiscale, peso_luogo_nascita, soglia_duplicato_certo,
  soglia_duplicato_probabile, soglia_duplicato_possibile
) VALUES (
  'Standard MPI', 
  'Algoritmo standard per rilevamento duplicati anagrafico',
  0.25, 0.30, 0.25, 0.40, 0.15, 
  95.00, 85.00, 70.00
)
ON CONFLICT (nome) DO NOTHING;

-- Dati lookup base
INSERT INTO tipi_documento (codice, descrizione) VALUES 
('CI', 'Carta di Identità'),
('PP', 'Passaporto'),
('PAT', 'Patente di Guida'),
('PE', 'Permesso di Soggiorno')
ON CONFLICT (codice) DO NOTHING;

INSERT INTO tipi_relazione (codice, descrizione, descrizione_inversa) VALUES 
('GENITORE', 'Genitore', 'Figlio/a'),
('CONIUGE', 'Coniuge', 'Coniuge'),
('FRATELLO', 'Fratello/Sorella', 'Fratello/Sorella'),
('FIGLIO', 'Figlio/a', 'Genitore'),
('TUTORE', 'Tutore Legale', 'Tutelato/a'),
('NONNO', 'Nonno/a', 'Nipote'),
('ZIO', 'Zio/a', 'Nipote')
ON CONFLICT (codice) DO NOTHING;

-- ========================================
-- NOTE STORED PROCEDURES
-- ========================================

-- Le stored procedures per la gestione transazionale delle anagrafiche
-- dovranno essere convertite separatamente da MySQL a PostgreSQL:
-- 
-- Per PostgreSQL utilizzare funzioni PL/pgSQL invece di stored procedures:
-- - Funzione per inserimento anagrafica transazionale con audit
-- - Funzione per aggiornamento anagrafica transazionale con audit  
-- - Funzione per soft delete anagrafica transazionale con audit
-- - Funzione per ripristino soft delete (se dati non pseudonimizzati)