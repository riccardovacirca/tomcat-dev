# Guida CSV per PostgreSQL MPI

## 📋 Panoramica

Questo documento descrive le precauzioni e le best practices per creare correttamente file CSV compatibili con il sistema MPI PostgreSQL.

## 🔧 Formato CSV Richiesto

### Separatori e Delimitatori
- **Separatore**: `;` (punto e virgola)
- **Delimitatore stringhe**: `"` (doppi apici)
- **Escape**: `""` (doppi apici doppi per escape)
- **Encoding**: UTF-8

### Esempio Formato Base
```csv
"campo1";"campo2";"campo3"
"valore1";"valore2";"valore3"
```

## ⚠️ Gestione Valori NULL

### ❌ SBAGLIATO
```csv
"codice";"nome";"data_inizio"
"TEST";"Nome Test";""
"TEST2";"Nome Test 2";
```

### ✅ CORRETTO
```csv
"codice";"nome";"data_inizio"
"TEST";"Nome Test";\N
"TEST2";"Nome Test 2";\N
```

**Regola importante**: Usare `\N` (senza virgolette) per rappresentare valori NULL in PostgreSQL.

## 📅 Gestione Date

### Formato Date Supportato
- **Formato**: `YYYY-MM-DD`
- **NULL**: `\N`

### Esempi
```csv
"codice";"data_inizio";"data_fine"
"ATTIVO";"2023-01-15";\N
"SCADUTO";"2020-01-01";"2023-12-31"
"FUTURO";"2025-06-01";\N
```

## 🔢 Gestione Boolean

### Valori Accettati
- **TRUE**: `"TRUE"`, `"true"`, `"T"`, `"1"`
- **FALSE**: `"FALSE"`, `"false"`, `"F"`, `"0"`
- **NULL**: `\N`

### Esempi
```csv
"codice";"attivo";"verificato"
"TEST1";"TRUE";"FALSE"
"TEST2";"true";\N
"TEST3";"1";"0"
```

## 📝 Gestione Stringhe

### Caratteri Speciali
- **Virgolette nelle stringhe**: Usare `""` (escape)
- **Punto e virgola**: Racchiudere in virgolette
- **A capo**: Supportato all'interno delle virgolette

### Esempi
```csv
"codice";"descrizione";"note"
"TEST1";"Descrizione ""con virgolette""";"Nota semplice"
"TEST2";"Testo con; punto e virgola";\N
"TEST3";"Testo multiriga
con a capo";"Note multiple"
```

## 🏥 File CSV Specifici MPI

### Domini Sanitari (`pg_mpi_install_domini.csv`)

**Struttura richiesta**:
```csv
"codice";"nome";"nome_breve";"data_inizio";"data_fine";"attivo";"creato_da"
```

**Campi obbligatori**:
- `codice`: Codice univoco (max 32 caratteri)
- `nome`: Nome completo (max 128 caratteri)  
- `attivo`: Boolean (`"TRUE"` o `"FALSE"`)
- `creato_da`: Utente creatore (max 128 caratteri)

**Campi opzionali**:
- `nome_breve`: Nome abbreviato (max 64 caratteri, usare `\N` se vuoto)
- `data_inizio`: Data di attivazione (`YYYY-MM-DD` o `\N`)
- `data_fine`: Data di disattivazione (`YYYY-MM-DD` o `\N`)

**Esempio completo**:
```csv
"codice";"nome";"nome_breve";"data_inizio";"data_fine";"attivo";"creato_da"
"DEFAULT";"Dominio Sanitario Principale";"Default";\N;\N;"TRUE";"system"
"ASL_RM1";"ASL Roma 1";"Roma 1";"2020-01-01";\N;"TRUE";"system"
"OSP_001";"Ospedale Generale";"Osp. Gen.";"2023-01-01";"2025-12-31";"TRUE";"admin"
```

## 🚨 Errori Comuni da Evitare

### 1. Stringhe vuote per NULL
```csv
❌ "codice";"data_inizio"
❌ "TEST";""
✅ "TEST";\N
```

### 2. Formato data errato
```csv
❌ "data";"15/01/2023"
❌ "data";"2023-1-15"
✅ "data";"2023-01-15"
```

### 3. Boolean come stringa non quotata
```csv
❌ "attivo";TRUE
✅ "attivo";"TRUE"
```

### 4. Separatori misti
```csv
❌ "campo1","campo2";"campo3"
✅ "campo1";"campo2";"campo3"
```

### 5. Encoding errato
- ❌ File salvati in Windows-1252 o Latin-1
- ✅ File salvati in UTF-8

## 🛠️ Tools Consigliati

### Editor di Testo
- **Visual Studio Code**: Con estensione "Excel to Markdown table"
- **Notepad++**: Con plugin CSV
- **Sublime Text**: Con Package CSV

### Fogli di Calcolo
- **LibreOffice Calc**: 
  - Salva come → CSV
  - Separatore: `;`
  - Delimitatore: `"`
  - Encoding: UTF-8

- **Excel**:
  - Salva come → CSV (delimitato da punto e virgola)
  - Verificare encoding UTF-8

### Verifica File
```bash
# Verifica encoding
file -i pg_mpi_install_domini.csv

# Verifica contenuto
head -5 pg_mpi_install_domini.csv

# Conta righe
wc -l pg_mpi_install_domini.csv
```

## 🔍 Debugging CSV

### Comando di Test PostgreSQL
```sql
-- Test caricamento in tabella temporanea
CREATE TEMP TABLE test_csv (LIKE domini_sanitari INCLUDING DEFAULTS);

COPY test_csv (codice, nome, nome_breve, data_inizio, data_fine, attivo, creato_da)
FROM '/tmp/test.csv'
WITH (
    FORMAT csv,
    DELIMITER ';',
    QUOTE '"',
    HEADER true,
    NULL '\N'
);

SELECT * FROM test_csv;
```

### Errori Comuni e Soluzioni

| Errore | Causa | Soluzione |
|--------|-------|-----------|
| `invalid input syntax for type date` | Data in formato errato | Usare `YYYY-MM-DD` o `\N` |
| `invalid input syntax for type boolean` | Boolean non riconosciuto | Usare `"TRUE"` o `"FALSE"` |
| `unterminated quoted string` | Virgolette non chiuse | Verificare escape `""` |
| `extra data after last expected column` | Colonne in più | Verificare intestazioni |

## ✅ Checklist Pre-Import

- [ ] File salvato in UTF-8
- [ ] Separatore `;` utilizzato
- [ ] Stringhe racchiuse in `"`
- [ ] Valori NULL rappresentati come `\N`
- [ ] Date in formato `YYYY-MM-DD`
- [ ] Boolean come `"TRUE"` o `"FALSE"`
- [ ] Intestazioni corrette
- [ ] Nessuna riga vuota alla fine
- [ ] Caratteri speciali gestiti correttamente

## 📞 Supporto

Per problemi con i file CSV:
1. Verificare il formato secondo questa guida
2. Testare con poche righe prima dell'import completo
3. Controllare i log di errore PostgreSQL per dettagli specifici
4. Utilizzare strumenti di validazione CSV online per verifiche preliminari