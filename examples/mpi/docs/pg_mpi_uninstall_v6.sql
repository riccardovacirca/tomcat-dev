-- ========================================
-- UNINSTALL SCRIPT ANAGRAFICHE v6.0 - PostgreSQL
-- Sistema di Interoperabilità Sanitaria MPI
-- RIMOZIONE COMPLETA SCHEMA E STORED PROCEDURES
-- COMPATIBILITÀ: PostgreSQL 12+
-- ========================================

-- ⚠️ ATTENZIONE: QUESTO SCRIPT ELIMINA TUTTE LE TABELLE E STORED PROCEDURES ⚠️
-- L'operazione è IRREVERSIBILE! Effettua un backup prima di procedere.

-- ========================================
-- RIMOZIONE STORED PROCEDURES
-- ========================================

-- Stored procedures principali
DROP FUNCTION IF EXISTS sp_insert_anagrafica_transazionale CASCADE;
DROP FUNCTION IF EXISTS sp_update_anagrafica_transazionale CASCADE;
DROP FUNCTION IF EXISTS sp_delete_anagrafica_transazionale CASCADE;
DROP FUNCTION IF EXISTS sp_restore_anagrafica_transazionale CASCADE;

-- Stored procedures gestione duplicati (v6.0)
DROP FUNCTION IF EXISTS sp_scan_duplicati_post_insert CASCADE;
DROP FUNCTION IF EXISTS sp_process_duplicate_scan_batch CASCADE;
DROP FUNCTION IF EXISTS sp_cleanup_duplicate_scan_queue CASCADE;

-- Funzioni utilità
DROP FUNCTION IF EXISTS decrypt_sensitive_data CASCADE;

-- ========================================
-- RIMOZIONE TABELLE (ordine dipendenze)
-- ========================================

-- Tabelle partizioni audit
DROP TABLE IF EXISTS log_audit_anagrafico_2023 CASCADE;
DROP TABLE IF EXISTS log_audit_anagrafico_2024 CASCADE;
DROP TABLE IF EXISTS log_audit_anagrafico_2025 CASCADE;
DROP TABLE IF EXISTS log_audit_anagrafico_default CASCADE;
DROP TABLE IF EXISTS log_audit_anagrafico CASCADE;

-- Tabelle dipendenti
DROP TABLE IF EXISTS duplicate_scan_queue CASCADE;
DROP TABLE IF EXISTS conflitti_merge CASCADE;
DROP TABLE IF EXISTS operazioni_merge CASCADE;
DROP TABLE IF EXISTS candidati_duplicati CASCADE;
DROP TABLE IF EXISTS blacklist_merge CASCADE;
DROP TABLE IF EXISTS relazioni_familiari CASCADE;
DROP TABLE IF EXISTS associazioni_paziente_dominio CASCADE;
DROP TABLE IF EXISTS dati_contatto_residenza CASCADE;
DROP TABLE IF EXISTS dati_sensibili_pazienti CASCADE;

-- Tabella principale
DROP TABLE IF EXISTS anagrafiche_pazienti CASCADE;

-- Tabelle di configurazione
DROP TABLE IF EXISTS domini_sanitari CASCADE;
DROP TABLE IF EXISTS stati_merge CASCADE;
DROP TABLE IF EXISTS algoritmi_matching CASCADE;
DROP TABLE IF EXISTS tipi_relazione CASCADE;
DROP TABLE IF EXISTS tipi_documento CASCADE;
DROP TABLE IF EXISTS codici_genere CASCADE;

-- Tabelle aggiuntive
DROP TABLE IF EXISTS log_errori_audit CASCADE;

-- ========================================
-- RIMOZIONE TIPI PERSONALIZZATI (ENUM)
-- ========================================

DROP TYPE IF EXISTS operazione_audit_type CASCADE;
DROP TYPE IF EXISTS scan_stato_type CASCADE;
DROP TYPE IF EXISTS scan_priorita_type CASCADE;
DROP TYPE IF EXISTS strategia_risoluzione_type CASCADE;
DROP TYPE IF EXISTS tipo_merge_type CASCADE;
DROP TYPE IF EXISTS priorita_type CASCADE;
DROP TYPE IF EXISTS stato_candidato_type CASCADE;
DROP TYPE IF EXISTS tipo_rilevamento_type CASCADE;
DROP TYPE IF EXISTS stato_associazione_type CASCADE;
DROP TYPE IF EXISTS stato_merge_type CASCADE;

-- ========================================
-- MESSAGGIO FINALE
-- ========================================

\echo 'UNINSTALL COMPLETATO: Tutte le tabelle e stored procedures sono state rimosse.'