# Database

Java database abstraction layer providing simplified database operations with JNDI integration, transaction support, and cursor-based result iteration.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Classes](#classes)
- [Methods](#methods)
- [Class Documentation](#class-documentation)
- [Method Documentation](#method-documentation)
- [Implementation](#implementation)

## Overview

The Database library provides a clean, unified interface for database operations in Java web applications. It abstracts the complexity of JDBC operations while maintaining full control over connections, transactions, and result handling.

### Key Features

- **JNDI Integration** - Seamless integration with application server connection pools
- **Transaction Support** - Complete transaction lifecycle management with rollback capabilities
- **Type-Safe Results** - Structured data types (Record, Recordset) for consistent data handling
- **Cursor Operations** - Memory-efficient result iteration for large datasets
- **Connection Pooling** - Automatic connection pool management through JNDI

### Dependencies

- Java 17+
- JNDI-compatible application server (Tomcat, etc.)
- Database driver (PostgreSQL, MySQL, SQLite, etc.)

## Installation

### Maven Dependency

```xml
<dependency>
  <groupId>jtools</groupId>
  <artifactId>database-lib</artifactId>
  <version>1.0-SNAPSHOT</version>
</dependency>
```

### JNDI Configuration

Configure database resource in `META-INF/context.xml`:

```xml
<Resource name="jdbc/MyDB"
          type="javax.sql.DataSource"
          maxTotal="20"
          maxIdle="10"
          maxWaitMillis="10000" />
```

## Quick Start

### Basic Usage

```java
import jtools.Database;

// Initialize and perform database operations
Database db = new Database("jdbc/MyDB");
db.open();

// Simple query
Database.Recordset users = db.select("SELECT * FROM users WHERE active = ?", true);
for (Database.Record user : users) {
    System.out.println("User: " + user.get("name"));
}

db.close();
```

### Transaction Example

```java
Database db = new Database("jdbc/MyDB");
db.open();
db.begin();

try {
    db.query("INSERT INTO users (name, email) VALUES (?, ?)", "John", "john@example.com");
    db.query("UPDATE user_stats SET total_users = total_users + 1");
    db.commit();
} catch (Exception e) {
    db.rollback();
    throw e;
} finally {
    db.close();
}
```

## Classes

#### Core Classes

class [Database](#Database) - Main database interface with connection and transaction management
class [Database.Record](#Database.Record) extends HashMap&lt;String, Object&gt; - Individual database record
class [Database.Recordset](#Database.Recordset) extends ArrayList&lt;Record&gt; - Collection of database records
class [Database.Cursor](#Database.Cursor) - Iterator for memory-efficient result processing

## Methods

#### Connection Management

void [open](#open)() - Opens database connection using JNDI datasource
void [close](#close)() - Closes database connection and releases resources
boolean [connected](#connected)() - Returns true if database connection is active

#### Transaction Management

void [begin](#begin)() - Starts database transaction (disables auto-commit)
void [commit](#commit)() - Commits current transaction and restores auto-commit
void [rollback](#rollback)() - Rolls back current transaction and restores auto-commit

#### Query Operations

int [query](#query)(String sql, Object... params) - Executes modification queries (INSERT, UPDATE, DELETE)
Recordset [select](#select)(String sql, Object... params) - Executes SELECT queries, returns all results
Cursor [cursor](#cursor)(String sql, Object... params) - Returns cursor for memory-efficient result iteration
long [lastInsertId](#lastInsertId)() - Returns ID of last inserted record

#### Cursor Operations

boolean [Cursor.next](#Cursor.next)() - Moves cursor to next result row
Object [Cursor.get](#Cursor.get)(String column) - Gets value from current row by column name
Record [Cursor.getRow](#Cursor.getRow)() - Gets entire current row as Record object
void [Cursor.close](#Cursor.close)() - Closes cursor and releases associated resources

# Class Documentation

## Database

```java
public class Database
```

**Description:**
Main database interface providing connection management, transaction control, and query execution. Handles JNDI datasource integration and connection pooling automatically.

**Constructor:**
```java
public Database(String jndiName)
```

**Parameters:**
- `jndiName` - JNDI resource name for database connection (e.g., "jdbc/MyDB")

## Database.Record

```java
public static class Record extends HashMap<String, Object>
```

**Description:**
Represents a single database record as a key-value map. Provides type-safe access to database column values with automatic type conversion.

**Inheritance:**
- Inherits all HashMap methods (get, put, containsKey, etc.)
- Implements Map&lt;String, Object&gt; interface

## Database.Recordset

```java
public static class Recordset extends ArrayList<Record>
```

**Description:**
Collection of database records providing list-like access to query results. Supports standard list operations and iteration.

**Inheritance:**
- Inherits all ArrayList methods (add, remove, size, get, etc.)
- Implements List&lt;Record&gt; interface

## Database.Cursor

```java
public static class Cursor
```

**Description:**
Memory-efficient iterator for large result sets. Provides row-by-row access to query results without loading entire dataset into memory.

**Resource Management:**
- Must be closed after use to release database resources
- Implements try-with-resources pattern compatibility

# Method Documentation

## open

```java
public void open() throws Exception
```

**Description:**
Opens database connection using JNDI datasource lookup. Establishes connection through application server's connection pool.

**Parameters:**
- None

**Return value:**
- `void` - No return value

**Exceptions:**
- `Exception` - JNDI lookup failure, connection establishment failure, or datasource configuration error

**Prerequisites:**
- JNDI resource must be properly configured in application server
- Database driver must be available in classpath

## close

```java
public void close()
```

**Description:**
Closes database connection and returns it to connection pool. Safe to call multiple times.

**Parameters:**
- None

**Return value:**
- `void` - No return value

**Resource Management:**
- Always call in finally block or use try-with-resources
- Connection returned to pool, not destroyed

## connected

```java
public boolean connected()
```

**Description:**
Checks if database connection is active and valid. Performs actual connection validation.

**Parameters:**
- None

**Return value:**
- `true` - Connection is active and valid
- `false` - No connection or connection is closed/invalid

## begin

```java
public void begin() throws Exception
```

**Description:**
Starts database transaction by disabling auto-commit mode. All subsequent operations will be part of the transaction until commit or rollback.

**Parameters:**
- None

**Return value:**
- `void` - No return value

**Exceptions:**
- `Exception` - Connection not available or transaction start failure

**Transaction State:**
- Sets auto-commit to false
- Must be followed by commit() or rollback()

## commit

```java
public void commit() throws Exception
```

**Description:**
Commits current transaction and restores auto-commit mode. Makes all transaction changes permanent.

**Parameters:**
- None

**Return value:**
- `void` - No return value

**Exceptions:**
- `Exception` - Connection not available or commit failure

**Transaction State:**
- Commits all pending changes
- Restores auto-commit to true

## rollback

```java
public void rollback() throws Exception
```

**Description:**
Rolls back current transaction and restores auto-commit mode. Discards all transaction changes.

**Parameters:**
- None

**Return value:**
- `void` - No return value

**Exceptions:**
- `Exception` - Connection not available or rollback failure

**Transaction State:**
- Discards all pending changes
- Restores auto-commit to true

## query

```java
public int query(String sql, Object... params) throws Exception
```

**Description:**
Executes modification queries (INSERT, UPDATE, DELETE) with parameter binding. Uses prepared statements to prevent SQL injection.

**Parameters:**
- `sql` - SQL statement with ? placeholders for parameters
- `params` - Variable arguments for parameter binding (in order)

**Return value:**
- `int` - Number of affected rows

**Exceptions:**
- `Exception` - Connection not available, invalid SQL, or execution failure

**Security:**
- Uses prepared statements for parameter binding
- Prevents SQL injection attacks

## select

```java
public Recordset select(String sql, Object... params) throws Exception
```

**Description:**
Executes SELECT queries and returns all results as Recordset. Loads complete result set into memory.

**Parameters:**
- `sql` - SQL SELECT statement with ? placeholders for parameters
- `params` - Variable arguments for parameter binding (in order)

**Return value:**
- `Recordset` - Collection of records containing all query results

**Exceptions:**
- `Exception` - Connection not available, invalid SQL, or execution failure

**Memory Usage:**
- Loads entire result set into memory
- Use cursor() for large result sets

## cursor

```java
public Cursor cursor(String sql, Object... params) throws Exception
```

**Description:**
Creates cursor for memory-efficient iteration over large result sets. Returns iterator that fetches rows on demand.

**Parameters:**
- `sql` - SQL SELECT statement with ? placeholders for parameters
- `params` - Variable arguments for parameter binding (in order)

**Return value:**
- `Cursor` - Iterator for result set navigation

**Exceptions:**
- `Exception` - Connection not available, invalid SQL, or execution failure

**Resource Management:**
- Must call cursor.close() after use
- Use try-with-resources pattern

## lastInsertId

```java
public long lastInsertId() throws Exception
```

**Description:**
Returns auto-generated key from last INSERT operation. Supports multiple database types with appropriate SQL.

**Parameters:**
- None

**Return value:**
- `long` - Auto-generated primary key value from last insert

**Exceptions:**
- `Exception` - Connection not available, unsupported database, or no recent insert

**Database Support:**
- MySQL: LAST_INSERT_ID()
- PostgreSQL: LASTVAL()
- SQLite: last_insert_rowid()
- SQL Server: @@IDENTITY
- Oracle: SEQ.CURRVAL FROM DUAL

## Cursor.next

```java
public boolean next() throws Exception
```

**Description:**
Moves cursor to next row in result set. Must be called before accessing row data.

**Parameters:**
- None

**Return value:**
- `true` - Successfully moved to next row, data available
- `false` - No more rows available, end of result set reached

**Exceptions:**
- `Exception` - Cursor operation failure or connection error

**Usage Pattern:**
```java
while (cursor.next()) {
    // Access row data
}
```

## Cursor.get

```java
public Object get(String column) throws Exception
```

**Description:**
Retrieves value from current cursor row by column name. Returns raw database value.

**Parameters:**
- `column` - Database column name (case-sensitive)

**Return value:**
- `Object` - Column value from current row (may be null)

**Exceptions:**
- `Exception` - Invalid column name, no current row, or access failure

**Type Casting:**
- Cast return value to appropriate type (String, Integer, etc.)
- Handle null values appropriately

## Cursor.getRow

```java
public Database.Record getRow() throws Exception
```

**Description:**
Retrieves entire current row as Record object containing all columns. Provides convenient access to complete row data.

**Parameters:**
- None

**Return value:**
- `Database.Record` - Record containing all columns from current row

**Exceptions:**
- `Exception` - No current row, metadata access failure, or row retrieval error

**Usage:**
- Access all columns at once
- Useful for logging or debugging
- Alternative to individual get() calls

## Cursor.close

```java
public void close()
```

**Description:**
Closes cursor and releases associated database resources. Closes underlying ResultSet and PreparedStatement.

**Parameters:**
- None

**Return value:**
- `void` - No return value

**Resource Management:**
- Always call after cursor usage
- Safe to call multiple times
- Required to prevent resource leaks

# Implementation

This configuration creates a connection pool that the Database class accesses
using the JNDI name `"jdbc/MyDB"`. The connection pooling is managed
automatically by Tomcat.


## Database

```java
package jtools;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import javax.naming.Context;
import javax.naming.InitialContext;
import javax.sql.DataSource;

public class Database
{
  private final String source;
  private Connection connection;

  public Database(String src) {
    this.source = src;
    this.connection = null;
  }

  // Nested static classes for structured data
  public static class Record extends HashMap<String, Object> {
  }

  public static class Recordset extends ArrayList<Record> {
  }

  public static class Cursor {
    private final ResultSet resultSet;
    private final PreparedStatement statement;

    public Cursor(ResultSet rs, PreparedStatement ps) {
      this.resultSet = rs;
      this.statement = ps;
    }

    public boolean next() throws Exception {
      return this.resultSet.next();
    }

    public Object get(String column) throws Exception {
      return this.resultSet.getObject(column);
    }

    public Record getRow() throws Exception {
      Record row = new Record();
      ResultSetMetaData meta = this.resultSet.getMetaData();
      int columnCount = meta.getColumnCount();

      for (int i = 1; i <= columnCount; i++) {
        row.put(meta.getColumnName(i), this.resultSet.getObject(i));
      }
      return row;
    }

    public void close() {
      try {
        if (this.resultSet != null) this.resultSet.close();
        if (this.statement != null) this.statement.close();
      } catch (SQLException e) {}
    }
  }

  // methods...
}
```

### Database::open

Opens a connection to the database server.
The JNDI name `jdbc/MyDB` must match the resource configured in the
application's context.xml.

```java
public void open() throws Exception
{
  Context ctx = new InitialContext();
  DataSource ds = (DataSource) ctx.lookup(this.source);
  this.connection = ds.getConnection();
}
```

### Database::close

Closes a connection to the database server

```java
public void close()
{
  if (this.connection != null) {
    try { this.connection.close(); } catch (SQLException e) {}
    this.connection = null;
  }
}
```

### Database::connected

Returns true if a connection is open

```java
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

Starts a transaction

```java
public void begin() throws Exception
{
  this.connection.setAutoCommit(false);
}
```

### Database::commit

Successfully commits a transaction

```java
public void commit() throws Exception
{
  this.connection.commit();
  this.connection.setAutoCommit(true);
}
```

### Database::rollback

Rolls back a transaction

```java
public void rollback() throws Exception
{
  this.connection.rollback();
  this.connection.setAutoCommit(true);
}
```

### Database::query

Executes modification queries (INSERT, UPDATE, DELETE)

```java
public int query(String sql, Object... params)
    throws Exception
{
  if (this.connection == null || this.connection.isClosed()) {
    throw new Exception("Connection not available");
  }
  if (sql == null || sql.trim().isEmpty()) {
    throw new Exception("Invalid SQL");
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

Executes selection queries (SELECT)

```java
public Recordset select(String sql, Object... params)
    throws Exception
{
  if (this.connection == null || this.connection.isClosed()) {
    throw new Exception("Connection not available");
  }
  if (sql == null || sql.trim().isEmpty()) {
    throw new Exception("Invalid SQL");
  }

  PreparedStatement ps = this.connection.prepareStatement(sql);
  for (int i = 0; i < params.length; i++) {
    ps.setObject(i + 1, params[i]);
  }
  ResultSet rs = ps.executeQuery();

  Recordset result = new Recordset();
  ResultSetMetaData meta = rs.getMetaData();
  int columnCount = meta.getColumnCount();

  while (rs.next()) {
    Record row = new Record();
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

Returns the ID of the last inserted record

```java
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
    throw new Exception("Unsupported database: " + dbProduct);
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

Returns a cursor to iterate over results

```java
public Cursor cursor(String sql, Object... params) throws Exception {
  if (this.connection == null || this.connection.isClosed()) {
    throw new Exception("Connection not available");
  }
  if (sql == null || sql.trim().isEmpty()) {
    throw new Exception("Invalid SQL");
  }

  PreparedStatement ps = this.connection.prepareStatement(sql);
  for (int i = 0; i < params.length; i++) {
    ps.setObject(i + 1, params[i]);
  }
  ResultSet rs = ps.executeQuery();
  return new Cursor(rs, ps);
}
```

### Database Usage Example

```java
import jtools.Database;

// Initialize database connection
Database db = new Database("jdbc/MyDB");

try {
    // Open connection
    db.open();

    if (db.connected()) {
        // Start transaction
        db.begin();

        try {
            // Execute INSERT query
            int insertedRows = db.query(
                "INSERT INTO users (name, email, active) VALUES (?, ?, ?)",
                "John Doe", "john@example.com", true
            );
            System.out.println("Inserted rows: " + insertedRows);

            // Get last inserted ID
            long userId = db.lastInsertId();
            System.out.println("New user ID: " + userId);

            // Execute UPDATE query
            int updatedRows = db.query(
                "UPDATE users SET active = ? WHERE id = ?",
                false, userId
            );
            System.out.println("Updated rows: " + updatedRows);

            // Execute SELECT query
            Database.Recordset users = db.select(
                "SELECT id, name, email, active FROM users WHERE id = ?",
                userId
            );

            for (Database.Record user : users) {
                System.out.println("User: " + user.get("name") +
                                 " (" + user.get("email") + ")");
            }

            // Commit transaction
            db.commit();

        } catch (Exception e) {
            // Rollback on error
            db.rollback();
            throw e;
        }
    }

} catch (Exception e) {
    e.printStackTrace();
} finally {
    // Close connection
    db.close();
}
```


### Database::Cursor

The Cursor is now a nested static class within Database, providing methods to iterate through query results:

- `next()` - Moves to the next row
- `get(String column)` - Gets a specific column value
- `getRow()` - Gets the entire row as a Record
- `close()` - Closes the cursor and releases resources

### Cursor Usage Example

```java
import jtools.Database;

// Initialize database connection
Database db = new Database("jdbc/MyDB");

try {
  // Open connection
  db.open();

  if (db.connected()) {
    // Create cursor for large result set
    Database.Cursor cursor = db.cursor(
      "SELECT id, name, email, active, created_at FROM users WHERE active = ? ORDER BY created_at",
      true
    );

    try {
      System.out.println("Processing active users:");
      // Iterate through results using cursor
      while (cursor.next()) {
        // Method 1: Get entire row as Record
        Database.Record userRecord = cursor.getRow();
        System.out.println("Complete record: " + userRecord);

        // Method 2: Get individual column values (original approach)
        Long id = (Long) cursor.get("id");
        String name = (String) cursor.get("name");
        String email = (String) cursor.get("email");
        Boolean active = (Boolean) cursor.get("active");
        java.sql.Timestamp createdAt = (java.sql.Timestamp) cursor.get("created_at");

        // Method 3: Access values from the Record
        Long idFromRecord = (Long) userRecord.get("id");
        String nameFromRecord = (String) userRecord.get("name");

        // Process each row efficiently
        System.out.printf("ID: %d, Name: %s, Email: %s, Active: %s, Created: %s%n",
                          id, name, email, active, createdAt);

        // Example: Process in batches or apply business logic
        if (id % 100 == 0) {
            System.out.println("Processed " + id + " records...");
        }
      }

    } finally {
      // Always close cursor to free resources
      cursor.close();
    }

    // Example: Using cursor with transactions
    db.begin();
    try {
        Database.Cursor inactiveCursor = db.cursor(
          "SELECT id FROM users WHERE active = ? AND last_login < ?",
          false, "2023-01-01"
        );

        try {
          while (inactiveCursor.next()) {
            // Option 1: Get specific field
            Long userId = (Long) inactiveCursor.get("id");

            // Option 2: Get entire row (useful for logging/debugging)
            Database.Record inactiveUser = inactiveCursor.getRow();
            System.out.println("Deleting user: " + inactiveUser);

            // Delete inactive users in transaction
            db.query("DELETE FROM users WHERE id = ?", userId);
          }
        } finally {
          inactiveCursor.close();
        }

        db.commit();
        System.out.println("Inactive users cleaned up successfully");

    } catch (Exception e) {
        db.rollback();
        System.err.println("Error during cleanup: " + e.getMessage());
    }
  }
} catch (Exception e) {
  e.printStackTrace();
} finally {
  // Close database connection
  db.close();
}
```

## Build library

### Create new library project

```bash
make lib name=database-lib
cd projects/database-lib
```

### Set groupId

```bash
cd src/main/java
mv com/example jtools
```

### Rename class packages

```java
// Set package to: package jtools;
```

### Add class files to the project

```
projects/database-lib/
├── pom.xml
└── src/
    └── main/
        └── java/
            └── jtools/
                └── Database.java
```

### Build library

```bash
make build
```

### Install locally

```bash
make install
```

## Distribute

### Case 1: Complete project transfer

```bash
# 1. Transfer the entire directory
scp -r projects/database-lib/ destination:/path/to/projects/

# 2. In the destination container
cd /path/to/projects/database-lib
mvn install
```

### Case 2: JAR-only transfer

```bash
# 1. Transfer only the JAR
scp projects/database-lib/target/database-lib-1.0-SNAPSHOT.jar destination:/tmp/

# 2. In the destination container
mvn install:install-file \
  -Dfile=/tmp/database-lib-1.0-SNAPSHOT.jar \
  -DgroupId=jtools \
  -DartifactId=database-lib \
  -Dversion=1.0-SNAPSHOT \
  -Dpackaging=jar
```

### Case 3: Direct copy to WEB-INF/lib

```bash
# 1. Transfer the JAR to the webapp
scp projects/database-lib/target/database-lib-1.0-SNAPSHOT.jar destination:/webapp/WEB-INF/lib/

# 2. No dependency needed in pom.xml
# 3. Restart Tomcat
```

## Using in the application

### Configure webapp pom.xml (Cases 1 and 2)

```xml
<dependency>
  <groupId>jtools</groupId>
  <artifactId>database-lib</artifactId>
  <version>1.0-SNAPSHOT</version>
</dependency>
```

### Import in code

```java
import jtools.Database;

Database db = new Database("jdbc/MyDB");
db.open();
Database.Recordset users = db.select("SELECT * FROM users WHERE active = ?", true);
db.close();
```

---
@2020-2025 Riccardo Vacirca - All right reserved.