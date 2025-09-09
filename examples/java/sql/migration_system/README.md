# Database Migration System

Sistema di migration automatico per applicazioni Java Servlet che consente di gestire automaticamente la creazione e l'evoluzione del database al primo avvio dell'applicazione.

## Caratteristiche

- **Auto-setup**: Database si crea automaticamente al primo deploy
- **Versioning**: Tracking di tutte le migration applicate
- **Idempotent**: Può essere eseguito più volte senza problemi
- **Rollback support**: Preparato per rollback future
- **Transaction safety**: Ogni migration è atomica
- **No external tools**: Tutto interno all'app Java

## Struttura dei File

```
src/main/java/com/example/todo/
├── migration/
│   ├── Migration.java                    # Interface base per migrations
│   ├── MigrationManager.java            # Gestore principale migrations
│   ├── CreateTodosTableMigration.java   # Migration specifica
│   └── AddTodosIndexesMigration.java    # Migration specifica
└── listener/
    └── DatabaseMigrationListener.java   # Listener per avvio automatico
```

## Come Funziona

### 1. Avvio Applicazione
```
1. Tomcat starts → DatabaseMigrationListener.contextInitialized()
2. MigrationManager.runMigrations()
3. Check/Create schema_migrations table
4. Compare applied vs available migrations
5. Execute missing migrations in order
6. Record successful migrations
7. App ready to serve requests
```

### 2. Schema Migrations Table
La tabella `schema_migrations` traccia le migration applicate:

| version | description | applied_at | execution_time_ms |
|---------|-------------|------------|-------------------|
| 20240109_001 | Create todos table | 2024-01-09 10:30:00 | 45 |
| 20240109_002 | Add indexes to todos table | 2024-01-09 10:30:01 | 23 |

## Implementazione

### 1. Migration Manager

```java
// src/main/java/com/example/todo/migration/MigrationManager.java
package com.example.todo.migration;

import javax.naming.Context;
import javax.naming.InitialContext;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

public class MigrationManager {
    private final DataSource dataSource;
    private static final String MIGRATION_TABLE = "schema_migrations";
    
    public MigrationManager() throws Exception {
        Context ctx = new InitialContext();
        this.dataSource = (DataSource) ctx.lookup("java:comp/env/jdbc/TodoDB");
    }
    
    public void runMigrations() {
        try (Connection conn = dataSource.getConnection()) {
            // 1. Crea tabella migrations se non esiste
            ensureMigrationTable(conn);
            
            // 2. Ottieni migrations già applicate
            List<String> appliedMigrations = getAppliedMigrations(conn);
            
            // 3. Ottieni tutte le migrations disponibili
            List<Migration> availableMigrations = getAvailableMigrations();
            
            // 4. Applica migrations mancanti
            for (Migration migration : availableMigrations) {
                if (!appliedMigrations.contains(migration.getVersion())) {
                    applyMigration(conn, migration);
                }
            }
            
            System.out.println("✅ Database migrations completed successfully");
            
        } catch (SQLException e) {
            throw new RuntimeException("Failed to run migrations", e);
        }
    }
    
    private void ensureMigrationTable(Connection conn) throws SQLException {
        String sql = """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(50) PRIMARY KEY,
                description VARCHAR(255),
                applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                execution_time_ms BIGINT
            )
            """;
        
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(sql);
        }
    }
    
    private List<String> getAppliedMigrations(Connection conn) throws SQLException {
        String sql = "SELECT version FROM schema_migrations ORDER BY version";
        List<String> applied = new ArrayList<>();
        
        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            while (rs.next()) {
                applied.add(rs.getString("version"));
            }
        }
        
        return applied;
    }
    
    private List<Migration> getAvailableMigrations() {
        List<Migration> migrations = new ArrayList<>();
        
        // Definisci migrations in ordine cronologico
        migrations.add(new CreateTodosTableMigration());
        migrations.add(new AddTodosIndexesMigration());
        // Aggiungi future migrations qui...
        
        return migrations;
    }
    
    private void applyMigration(Connection conn, Migration migration) throws SQLException {
        System.out.println("Applying migration: " + migration.getDescription());
        
        long startTime = System.currentTimeMillis();
        
        try {
            conn.setAutoCommit(false);
            
            // Esegui migration
            migration.up(conn);
            
            // Registra migration come applicata
            recordMigration(conn, migration, System.currentTimeMillis() - startTime);
            
            conn.commit();
            
            System.out.println("✅ Applied: " + migration.getVersion() + " - " + migration.getDescription());
            
        } catch (SQLException e) {
            conn.rollback();
            throw new SQLException("Failed to apply migration " + migration.getVersion(), e);
        } finally {
            conn.setAutoCommit(true);
        }
    }
    
    private void recordMigration(Connection conn, Migration migration, long executionTimeMs) throws SQLException {
        String sql = "INSERT INTO schema_migrations (version, description, execution_time_ms) VALUES (?, ?, ?)";
        
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, migration.getVersion());
            stmt.setString(2, migration.getDescription());
            stmt.setLong(3, executionTimeMs);
            stmt.executeUpdate();
        }
    }
}
```

### 2. Interface Migration Base

```java
// src/main/java/com/example/todo/migration/Migration.java
package com.example.todo.migration;

import java.sql.Connection;
import java.sql.SQLException;

public interface Migration {
    String getVersion();
    String getDescription();
    void up(Connection connection) throws SQLException;
    void down(Connection connection) throws SQLException; // Per rollback futuro
}
```

### 3. Migration Concrete - Creazione Tabella

```java
// src/main/java/com/example/todo/migration/CreateTodosTableMigration.java
package com.example.todo.migration;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;

public class CreateTodosTableMigration implements Migration {
    
    @Override
    public String getVersion() {
        return "20240109_001";
    }
    
    @Override
    public String getDescription() {
        return "Create todos table";
    }
    
    @Override
    public void up(Connection conn) throws SQLException {
        String sql = """
            CREATE TABLE todos (
                id BIGSERIAL PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                completed BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP,
                completed_at TIMESTAMP,
                priority VARCHAR(20) DEFAULT 'MEDIUM' CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),
                category VARCHAR(100)
            )
            """;
        
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(sql);
        }
    }
    
    @Override
    public void down(Connection conn) throws SQLException {
        String sql = "DROP TABLE IF EXISTS todos";
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(sql);
        }
    }
}
```

### 4. Migration Concrete - Aggiunta Indici

```java
// src/main/java/com/example/todo/migration/AddTodosIndexesMigration.java
package com.example.todo.migration;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;

public class AddTodosIndexesMigration implements Migration {
    
    @Override
    public String getVersion() {
        return "20240109_002";
    }
    
    @Override
    public String getDescription() {
        return "Add indexes to todos table";
    }
    
    @Override
    public void up(Connection conn) throws SQLException {
        String[] indexes = {
            "CREATE INDEX IF NOT EXISTS idx_todos_completed ON todos(completed)",
            "CREATE INDEX IF NOT EXISTS idx_todos_category ON todos(category)",
            "CREATE INDEX IF NOT EXISTS idx_todos_priority ON todos(priority)",
            "CREATE INDEX IF NOT EXISTS idx_todos_created_at ON todos(created_at)"
        };
        
        try (Statement stmt = conn.createStatement()) {
            for (String indexSql : indexes) {
                stmt.execute(indexSql);
            }
        }
    }
    
    @Override
    public void down(Connection conn) throws SQLException {
        String[] dropIndexes = {
            "DROP INDEX IF EXISTS idx_todos_completed",
            "DROP INDEX IF EXISTS idx_todos_category", 
            "DROP INDEX IF EXISTS idx_todos_priority",
            "DROP INDEX IF EXISTS idx_todos_created_at"
        };
        
        try (Statement stmt = conn.createStatement()) {
            for (String dropSql : dropIndexes) {
                stmt.execute(dropSql);
            }
        }
    }
}
```

### 5. ServletContextListener per Auto-Migration

```java
// src/main/java/com/example/todo/listener/DatabaseMigrationListener.java
package com.example.todo.listener;

import com.example.todo.migration.MigrationManager;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

@WebListener
public class DatabaseMigrationListener implements ServletContextListener {
    
    @Override
    public void contextInitialized(ServletContextEvent sce) {
        try {
            System.out.println("🔄 Starting database migrations...");
            
            MigrationManager migrationManager = new MigrationManager();
            migrationManager.runMigrations();
            
            System.out.println("✅ Database initialization completed");
            
        } catch (Exception e) {
            System.err.println("❌ Database migration failed: " + e.getMessage());
            e.printStackTrace();
            
            // Decidere se far fallire l'avvio dell'app o continuare
            throw new RuntimeException("Database migration failed", e);
        }
    }
    
    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        System.out.println("🛑 Todo application shutting down");
    }
}
```

### 6. Configurazione web.xml (opzionale)

Se non usi l'annotation `@WebListener`, aggiungi al web.xml:

```xml
<listener>
    <listener-class>com.example.todo.listener.DatabaseMigrationListener</listener-class>
</listener>
```

## Aggiungere Nuove Migrations

### Esempio: Aggiunta Colonna Due Date

```java
// src/main/java/com/example/todo/migration/AddTodoDueDateMigration.java
package com.example.todo.migration;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;

public class AddTodoDueDateMigration implements Migration {
    
    @Override
    public String getVersion() {
        return "20240115_003";
    }
    
    @Override
    public String getDescription() {
        return "Add due_date column to todos";
    }
    
    @Override
    public void up(Connection conn) throws SQLException {
        String sql = "ALTER TABLE todos ADD COLUMN due_date DATE";
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(sql);
        }
    }
    
    @Override
    public void down(Connection conn) throws SQLException {
        String sql = "ALTER TABLE todos DROP COLUMN IF EXISTS due_date";
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(sql);
        }
    }
}
```

**Importante**: Aggiungere la nuova migration in `MigrationManager.getAvailableMigrations()`:

```java
private List<Migration> getAvailableMigrations() {
    List<Migration> migrations = new ArrayList<>();
    
    migrations.add(new CreateTodosTableMigration());
    migrations.add(new AddTodosIndexesMigration());
    migrations.add(new AddTodoDueDateMigration()); // ← Nuova migration
    
    return migrations;
}
```

## Convenzioni di Naming

### Versioni Migration
- **Formato**: `YYYYMMDD_NNN` (Anno/Mese/Giorno_Sequenza)
- **Esempi**: 
  - `20240109_001` - Prima migration del 9 gennaio 2024
  - `20240109_002` - Seconda migration dello stesso giorno
  - `20240115_003` - Prima migration del 15 gennaio 2024

### Nomi Classi
- **Pattern**: `[Action][Entity][Migration]`
- **Esempi**:
  - `CreateTodosTableMigration`
  - `AddTodosIndexesMigration` 
  - `AddUserColumnMigration`
  - `UpdateTodosConstraintsMigration`

## Verifica Migrations Applicate

```sql
-- Vedere tutte le migration applicate
SELECT version, description, applied_at, execution_time_ms 
FROM schema_migrations 
ORDER BY version;

-- Verificare struttura tabella todos
\d todos;

-- Verificare indici
\di todos*;
```

## Troubleshooting

### Migration Fallisce
1. **Controllare logs**: Tomcat mostrerà l'errore SQL specifico
2. **Rollback automatico**: Ogni migration è in transazione
3. **Fix e restart**: Correggere il codice SQL e riavviare l'app

### Migration Parzialmente Applicata
1. **Controllare schema_migrations**: Vedere quale migration è registrata
2. **Cleanup manuale**: Rimuovere record da `schema_migrations` se necessario
3. **Restart**: L'app riproverà la migration

### Performance Migrations
- **Migrations pesanti**: Considerare esecuzione in maintenance window
- **Indici**: Creare indici in migration separate
- **Dati**: Separare structure changes da data migrations

## Estensioni Possibili

1. **File-based migrations**: Caricare SQL da file invece che codice Java
2. **Migration rollback**: Implementare comando per rollback automatico
3. **Migration CLI**: Tool command-line per gestire migrations
4. **Environment-specific**: Migrations diverse per dev/prod
5. **Backup automatico**: Backup prima di applicare migrations

## Best Practices

1. **Sempre testare migrations** su copia del database
2. **Migrations irreversibili**: Fare backup prima dell'applicazione
3. **Ordine cronologico**: Versioni devono essere in ordine temporale
4. **Atomicità**: Ogni migration deve essere atomica (transazione)
5. **Idempotenza**: Migration deve poter essere eseguita più volte
6. **Backward compatibility**: Non rompere applicazioni esistenti

---

**Questo sistema fornisce un controllo completo sulle evolution del database direttamente dall'applicazione Java, eliminando la necessità di gestire migrations esterne.**