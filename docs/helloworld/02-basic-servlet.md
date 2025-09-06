# Step 2: Basic Servlet

## Create HelloWorldServlet.java

File: `src/main/java/com/example/servlet/HelloWorldServlet.java`

### Step 1: Package e imports

```java
// Dichiara il package (deve corrispondere alla struttura cartelle)
package com.example.servlet;

// Import delle classi necessarie per servlet HTTP
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

// Import per gestione I/O
import java.io.IOException;
import java.io.PrintWriter;
```

### Step 2: Dichiarazione classe e mapping URL

```java
// Annotation che mappa l'URL /api/hello a questo servlet
@WebServlet("/api/hello")
public class HelloWorldServlet extends HttpServlet {
    // La classe eredita da HttpServlet per gestire richieste HTTP
```

### Step 3: Metodo doGet per richieste GET

```java
    @Override  // Sovrascrive il metodo della classe padre
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        
        // Imposta il tipo di contenuto della risposta
        response.setContentType("text/plain");
        
        // Ottiene il writer per scrivere la risposta
        PrintWriter out = response.getWriter();
        
        // Scrive il messaggio nella risposta
        out.print("Hello World!");
        
        // Forza l'invio dei dati al client
        out.flush();
    }
}
```

### Codice completo

```java
package com.example.servlet;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;

@WebServlet("/api/hello")
public class HelloWorldServlet extends HttpServlet {
    
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        
        response.setContentType("text/plain");
        
        PrintWriter out = response.getWriter();
        out.print("Hello World!");
        out.flush();
    }
}
```

## Key concepts

### `@WebServlet("/api/hello")` - URL Mapping
Annotation che collega un URL specifico **all'intera servlet**. Quando un client fa una richiesta a `/api/hello`, Tomcat instrada la chiamata a questo servlet.

**Importante:** `@WebServlet` mappa l'URL alla classe, non ai singoli metodi. Una volta che la richiesta arriva al servlet, Tomcat sceglie automaticamente il metodo corretto:
- Richiesta GET → chiama `doGet()`
- Richiesta POST → chiama `doPost()`
- Richiesta PUT → chiama `doPut()`
- Richiesta DELETE → chiama `doDelete()`

**Formato URL completo:** `http://localhost:9292/helloworld/api/hello`
- `helloworld` = nome dell'applicazione (dal WAR)
- `/api/hello` = path definito nell'annotation

**Pattern possibili:**
```java
@WebServlet("/api/hello")     // Path fisso
@WebServlet("/api/users/*")   // Path con wildcard
@WebServlet("*.json")         // Extension mapping
```

**Non è possibile** associare path diversi per metodo diverso nella stessa servlet. Per questo servono servlet separate o framework come Spring.

### `HttpServlet` - Classe Base
Classe fornita da Jakarta EE che gestisce il protocollo HTTP. Estendendola, ereditiamo:
- Gestione automatica delle richieste HTTP
- Metodi per GET, POST, PUT, DELETE
- Parsing degli header e parametri
- Gestione delle sessioni

### `doGet()` - Gestore Richieste GET
Metodo chiamato automaticamente quando arriva una richiesta HTTP GET. Parametri:
- `HttpServletRequest request` - Contiene dati della richiesta (parametri, header)
- `HttpServletResponse response` - Per costruire la risposta al client

### `PrintWriter` - Output Stream
Oggetto per scrivere la risposta HTTP. Metodi principali:
- `print()` - Scrive testo senza andare a capo
- `println()` - Scrive testo con andare a capo
- `flush()` - Forza l'invio immediato dei dati

### `throws ServletException, IOException`
Dichiara che il metodo può lanciare eccezioni. Tomcat le gestisce automaticamente:
- `ServletException` - Errori specifici del servlet
- `IOException` - Errori di input/output (rete, file)

## Test

Ora che abbiamo un servlet funzionante, compiliamolo e testiamolo:

```bash
mvn package
# Deploy and visit: http://localhost:9292/helloworld/api/hello
```

**Cosa succede:**
1. Maven compila `HelloWorldServlet.java` in `HelloWorldServlet.class`
2. Crea il WAR con la classe compilata
3. Dopo il deploy, Tomcat carica il servlet
4. L'URL `/api/hello` restituirà il testo "Hello World!"

**Output atteso:** Pagina web con il testo `Hello World!`