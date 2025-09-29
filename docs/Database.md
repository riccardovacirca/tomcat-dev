# Database

## DatabaseInterface

```java
package org.example.database;

import java.util.List;
import java.util.Map;

public interface DatabaseInterface
{
  void open() throws Exception;
  void close();
  boolean connected();

  void begin() throws Exception;
  void commit() throws Exception;
  void rollback() throws Exception;

  int query(String sql, Object... params) throws Exception;
  List<Map<String,Object>> select(String sql, Object... params) throws Exception;
  CursorInterface cursor(String sql, Object... params) throws Exception;

  long lastInsertId() throws Exception;
}
```

## Database

```java
package org.example.database;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.naming.Context;
import javax.naming.InitialContext;
import javax.sql.DataSource;

public class Database implements DatabaseInterface
{
  private final String source;
  private Connection connection;

  public Database(String src) {
    this.source = src;
    this.connection = null;
  }

  // methods...
}
```

### Database::open

Apre una connessione con il server di database.
Il nome JNDI `jdbc/MyDB` deve corrispondere alla risorsa configurata nel
context.xml dell'applicazione.

```java
@Override
public void open() throws Exception
{
  Context ctx = new InitialContext();
  DataSource ds = (DataSource) ctx.lookup(this.source);
  this.connection = ds.getConnection();
}
```

### Database::close

Chiude una connessione con il server di database

```java
@Override
public void close()
{
  if (this.connection != null) {
    try { this.connection.close(); } catch (SQLException e) {}
    this.connection = null;
  }
}
```

### Database::connected

Restituisce true se una connessione è aperta

```java
@Override
public boolean connected()
{
  try {
    return this.connection != null && !this.connection.isClosed();
  } catch (SQLException e) {
    return false;
  }
}
```

### Database::begin

Avvia una transazione

```java
@Override
public void begin() throws Exception
{
  this.connection.setAutoCommit(false);
}
```

### Database::commit

Chiude con successo una transazione

```java
@Override
public void commit() throws Exception
{
  this.connection.commit();
  this.connection.setAutoCommit(true);
}
```

### Database::rollback

Chiude con errore una transazione

```java
@Override
public void rollback() throws Exception
{
  this.connection.rollback();
  this.connection.setAutoCommit(true);
}
```

### Database::query

Esegue query di modifica (INSERT, UPDATE, DELETE)

```java
@Override
public int query(String sql, Object... params)
    throws Exception
{
  if (this.connection == null || this.connection.isClosed()) {
    throw new Exception("Connessione non disponibile");
  }
  if (sql == null || sql.trim().isEmpty()) {
    throw new Exception("SQL non valido");
  }

  PreparedStatement ps = this.connection.prepareStatement(sql);
  for (int i = 0; i < params.length; i++) {
    ps.setObject(i + 1, params[i]);
  }
  int result = ps.executeUpdate();
  ps.close();
  return result;
}
```

### Database::select

Esegue query di selezione (SELECT)

```java
@Override
public List<Map<String,Object>> select(String sql, Object... params)
    throws Exception
{
  if (this.connection == null || this.connection.isClosed()) {
    throw new Exception("Connessione non disponibile");
  }
  if (sql == null || sql.trim().isEmpty()) {
    throw new Exception("SQL non valido");
  }

  PreparedStatement ps = this.connection.prepareStatement(sql);
  for (int i = 0; i < params.length; i++) {
    ps.setObject(i + 1, params[i]);
  }
  ResultSet rs = ps.executeQuery();

  List<Map<String,Object>> result = new ArrayList<>();
  ResultSetMetaData meta = rs.getMetaData();
  int columnCount = meta.getColumnCount();

  while (rs.next()) {
    Map<String,Object> row = new HashMap<>();
    for (int i = 1; i <= columnCount; i++) {
      row.put(meta.getColumnName(i), rs.getObject(i));
    }
    result.add(row);
  }

  rs.close();
  ps.close();
  return result;
}
```

### Database::lastInsertId

Restituisce l'ID dell'ultimo record inserito

```java
@Override
public long lastInsertId()
    throws Exception
{
  String dbProduct = this.connection
    .getMetaData()
    .getDatabaseProductName()
    .toLowerCase();
  
  String query;

  if (dbProduct.contains("mysql")) {
    query = "SELECT LAST_INSERT_ID()";
  } else if (dbProduct.contains("postgresql")) {
    query = "SELECT LASTVAL()";
  } else if (dbProduct.contains("sqlite")) {
    query = "SELECT last_insert_rowid()";
  } else if (dbProduct.contains("sql server")) {
    query = "SELECT @@IDENTITY";
  } else if (dbProduct.contains("oracle")) {
    query = "SELECT SEQ.CURRVAL FROM DUAL";
  } else {
    throw new Exception("Database non supportato: " + dbProduct);
  }

  PreparedStatement ps = this.connection.prepareStatement(query);
  ResultSet rs = ps.executeQuery();
  long id = 0;
  if (rs.next()) {
    id = rs.getLong(1);
  }
  rs.close();
  ps.close();
  return id;
}
```

### Database::cursor

Restituisce un cursore per iterare sui risultati

```java
@Override
public CursorInterface cursor(String sql, Object... params) throws Exception {
  if (this.connection == null || this.connection.isClosed()) {
    throw new Exception("Connessione non disponibile");
  }
  if (sql == null || sql.trim().isEmpty()) {
    throw new Exception("SQL non valido");
  }

  PreparedStatement ps = this.connection.prepareStatement(sql);
  for (int i = 0; i < params.length; i++) {
    ps.setObject(i + 1, params[i]);
  }
  ResultSet rs = ps.executeQuery();
  return new Cursor(rs, ps);
}
```


## CursorInterface

```java
package org.example.database;

public interface CursorInterface extends AutoCloseable
{
  boolean next() throws Exception;
  Object get(String column) throws Exception;
  void close();
}
```

## Cursor

```java
package org.example.database;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class Cursor implements CursorInterface {
  private final ResultSet resultSet;
  private final PreparedStatement statement;

  public Cursor(ResultSet rs, PreparedStatement ps) {
    this.resultSet = rs;
    this.statement = ps;
  }

  // methods...
}
```

### Cursor::next

```java
@Override
public boolean next() throws Exception {
  return this.resultSet.next();
}
```

### Cursor::get

```java
  @Override
  public Object get(String column) throws Exception {
    return this.resultSet.getObject(column);
  }
```

### Cursor::close

```java
  @Override
  public void close() {
    try {
      if (this.resultSet != null) this.resultSet.close();
      if (this.statement != null) this.statement.close();
    } catch (SQLException e) {
    }
  }
```

## JNDI resource

```xml
<Resource name="jdbc/MyDB"
          type="javax.sql.DataSource"
          maxTotal="20"
          maxIdle="10"
          maxWaitMillis="10000" />
```

## Istruzioni per creazione libreria

### 1. Creare il progetto libreria

```bash
make lib name=database-helper
cd projects/database-helper
```

### 2. Allineare il groupId

Il Makefile generato usa `com.example` come groupId. Per allinearlo a `org.example`:

```bash
# Rinominare le directory
cd src/main/java
mv com/example org/example
```

**Modificare nei file Java il package declaration:**
```java
// Da: package com.example.database;
// A:   package org.example.database;
```

File da modificare: `CursorInterface.java`, `DatabaseInterface.java`, `Database.java`, `Cursor.java`

### 3. Struttura del progetto

```
projects/database-helper/
├── pom.xml
└── src/
    └── main/
        └── java/
            └── org/
                └── example/
                    └── database/
                        ├── CursorInterface.java
                        ├── DatabaseInterface.java
                        ├── Database.java
                        └── Cursor.java
```

Copiare le implementazioni dalle sezioni precedenti del documento nei rispettivi file.

### 4. Compilare la libreria

```bash
make build
```

### 5. Installare nel repository locale

```bash
make install
```

### 6. Distribuire e usare la libreria

#### Caso 1: Trasferimento completo del progetto

```bash
# 1. Trasferire l'intera directory
scp -r projects/database-helper/ destinazione:/path/to/projects/

# 2. Nel container destinazione
cd /path/to/projects/database-helper
mvn install
```

#### Caso 2: Trasferimento solo del JAR

```bash
# 1. Trasferire solo il JAR
scp projects/database-helper/target/database-helper-1.0-SNAPSHOT.jar destinazione:/tmp/

# 2. Nel container destinazione
mvn install:install-file \
  -Dfile=/tmp/database-helper-1.0-SNAPSHOT.jar \
  -DgroupId=org.example \
  -DartifactId=database-helper \
  -Dversion=1.0-SNAPSHOT \
  -Dpackaging=jar
```

#### Caso 3: Copia diretta in WEB-INF/lib

```bash
# 1. Trasferire il JAR nella webapp
scp projects/database-helper/target/database-helper-1.0-SNAPSHOT.jar destinazione:/webapp/WEB-INF/lib/

# 2. Non serve dependency nel pom.xml
# 3. Riavviare Tomcat
```

#### Configurazione webapp (Casi 1 e 2)

**Nel pom.xml della webapp aggiungere:**
```xml
<dependency>
  <groupId>org.example</groupId>
  <artifactId>database-helper</artifactId>
  <version>1.0-SNAPSHOT</version>
</dependency>
```

#### Esempio d'uso

```java
import org.example.database.Database;
import java.util.List;
import java.util.Map;

Database db = new Database("jdbc/MyDB");
db.open();
List<Map<String,Object>> users = db.select("SELECT * FROM users WHERE active = ?", true);
db.close();
```

---

@2020-2025 Riccardo Vacirca - All right reserved.