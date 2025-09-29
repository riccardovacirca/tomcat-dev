# Database

This document describes a database abstraction layer for Java web applications,
providing a clean interface for database operations with support for
transactions, prepared statements, and multiple database types.

## JNDI Configuration

JNDI (Java Naming and Directory Interface) is used to configure database
connections in Tomcat applications. The database connection is defined as a
resource in the application's `META-INF/context.xml` file and accessed by name
in the Java code.

```xml
<Resource name="jdbc/MyDB"
          type="javax.sql.DataSource"
          maxTotal="20"
          maxIdle="10"
          maxWaitMillis="10000" />
```

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