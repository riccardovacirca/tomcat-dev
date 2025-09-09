# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PostgreSQL-based Master Patient Index (MPI) system for healthcare data interoperability. The system manages patient demographics, duplicate detection, and merge operations for healthcare anagraphics (patient records).

## Key Commands

### Installation and Setup
- `./pg_mpi_install.sh -h <container> -u <user> -p <password> -d <database>` - Install schema and stored procedures
- `./pg_mpi_uninstall.sh -h <container> -u <user> -p <password> -d <database>` - Uninstall system
- `./pg_mpi_recreate_database.sh -h <container> -u <user> -p <password> -d <database>` - Recreate database

### Main Test Workflow
- `./pg_mpi.sh -h <container> -u <user> -p <password> -d <database>` - Complete test workflow (interactive)

### Dashboard Operations
- `./pg_mpi_dashboard.sh -h <container> -u <user> -p <password> -d <database>` - Interactive duplicate management dashboard
- `./pg_mpi_dashboard_merge.sh` - Process duplicate merge
- `./pg_mpi_dashboard_reject.sh` - Reject duplicate candidates
- `./pg_mpi_dashboard_postpone.sh` - Postpone duplicate processing
- `./pg_mpi_dashboard_blacklist.sh` - Blacklist duplicate pairs

### Data Operations
- `./pg_mpi_sql_insert_anagrafica.sh` - Insert patient demographics
- `./pg_mpi_sql_select_anagrafica.sh` - Query patient records
- `./pg_mpi_sql_update_anagrafica.sh` - Update patient data
- `./pg_mpi_sql_delete_anagrafica.sh` - Soft delete patient records
- `./pg_mpi_sql_restore_anagrafica.sh` - Restore deleted records

### Duplicate Detection
- `./pg_mpi_sql_duplicates_detect.sh` - Run duplicate detection algorithms
- `./pg_mpi_sql_duplicates_read_next.sh` - Get next duplicate for processing
- `./pg_mpi_sql_insert_duplicate.sh` - Insert test duplicate data

## System Architecture

### Database Layer (PostgreSQL 12+)
- **Core Tables**: `anagrafiche_pazienti`, `dati_sensibili_pazienti`, `dati_contatto_residenza`
- **Duplicate Management**: `candidati_duplicati`, `duplicati_blacklist`, `audit_duplicati`
- **Reference Data**: `codici_genere`, `tipi_documento`, `domini_sanitari`

### Stored Procedures (v6)
- `sp_insert_anagrafica_transazionale` - Transactional patient insert with duplicate detection
- `sp_update_anagrafica_transazionale` - Transactional patient updates
- `sp_delete_anagrafica_transazionale` - Soft delete with audit trail
- `sp_restore_anagrafica_transazionale` - Restore deleted records
- `sp_scan_duplicati_post_insert` - Post-insert duplicate scanning
- `sp_process_duplicate_scan_batch` - Batch duplicate processing

### Shell Script Architecture
- **Installation Scripts**: Handle database schema setup and stored procedure deployment
- **SQL Operation Scripts**: Wrapper scripts for database operations with parameter validation
- **Dashboard Scripts**: Interactive CLI tools for duplicate management
- **Utility Scripts**: Database maintenance and testing tools

### Key Design Patterns
- **Transactional Operations**: All patient data operations are wrapped in transactions
- **Audit Trail**: Comprehensive logging of all data modifications
- **Soft Deletes**: Records are marked as deleted rather than physically removed
- **Duplicate Detection**: Automatic scanning with configurable thresholds
- **Interactive Workflows**: Step-by-step user guidance for complex operations

## Development Workflow

### Database Development
1. Modify SQL schema files (`pg_mpi_install_v6.sql`, `pg_mpi_install_sp_*.sql`)
2. Test with `./pg_mpi_uninstall.sh` followed by `./pg_mpi_install.sh`
3. Run complete workflow test with `./pg_mpi.sh`

### Script Development
- All scripts use consistent parameter patterns: `-h <host> -u <user> -p <password> -d <database>`
- Scripts include built-in validation and error handling
- Use `set -e` for fail-fast behavior
- Docker-based PostgreSQL operations throughout

### CSV Data Format
- Delimiter: `;` (semicolon)
- String quotes: `"` (double quotes)
- NULL values: `\N` (backslash-N)
- Encoding: UTF-8
- See `pg_mpi_doc_csv.md` for detailed CSV formatting guidelines

## Important Notes

### Security Considerations
- Patient data includes sensitive healthcare information
- CF (Codice Fiscale) values are stored as hashed representations
- All database operations require authentication
- Audit trails maintain compliance records

### Data Integrity
- Foreign key constraints maintain referential integrity
- Duplicate detection uses scoring algorithms for match confidence
- Manual approval required for duplicate merge operations
- Blacklist system prevents inappropriate duplicate suggestions

### Docker Integration
- All database operations expect PostgreSQL running in Docker containers
- Container names are passed as parameters to all scripts
- Scripts handle Docker exec operations for database connectivity