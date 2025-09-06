# Step 2: Basic Servlet

## 🏗️ Struttura Directory Obbligatoria

**Prima di scrivere codice, è fondamentale capire DOVE posizionare il servlet e PERCHÉ.**

### Struttura Corretta del Progetto
```
helloworld/
├── src/main/java/                          ← Codice sorgente Java
│   └── com/example/servlet/                ← Package structure
│       └── HelloWorldServlet.java         ← Il nostro servlet
├── src/main/webapp/                        ← Risorse web
│   ├── WEB-INF/
│   │   └── web.xml                        ← Config opzionale
│   └── index.html                         ← File statici
└── pom.xml                                ← Configurazione Maven
```

### ⚠️ Posizionamento CRITICO

**✅ CORRETTO:**
- File: `src/main/java/com/example/servlet/HelloWorldServlet.java`
- Package: `package com.example.servlet;`

**❌ ERRORI COMUNI:**
```
❌ src/main/webapp/HelloWorldServlet.java     → NON viene compilato
❌ src/HelloWorldServlet.java                 → Struttura Maven sbagliata  
❌ com/example/HelloWorldServlet.java         → Package mismatch
❌ src/main/java/HelloWorldServlet.java       → Manca package structure
```

### 🔍 Perché Questa Struttura?

1. **Maven Standard Directory Layout**
   - `src/main/java/` = Root per codice sorgente Java
   - Maven sa automaticamente dove trovare i file da compilare

2. **Java Package System**
   - `com/example/servlet/` = Gerarchia di cartelle = Package Java
   - Previene conflitti di nomi tra classi
   - Segue convenzione reverse-domain (com.azienda.modulo)

3. **Tomcat Deployment Requirements**
   - Maven compila da `src/main/java/` a `target/classes/`
   - WAR impacchetta `target/classes/` in `WEB-INF/classes/`
   - Tomcat carica servlet da `WEB-INF/classes/com/example/servlet/`

### 🔄 Flusso di Deployment
```
src/main/java/com/example/servlet/HelloWorldServlet.java
                    ↓ (maven compile)
target/classes/com/example/servlet/HelloWorldServlet.class
                    ↓ (maven package)
target/helloworld.war → WEB-INF/classes/com/example/servlet/HelloWorldServlet.class
                    ↓ (tomcat deploy)
webapps/helloworld/WEB-INF/classes/com/example/servlet/HelloWorldServlet.class
```

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

## 🐛 Troubleshooting: Errori Comuni

### Errore: ClassNotFoundException
```
java.lang.ClassNotFoundException: com.example.servlet.HelloWorldServlet
```
**Causa:** Package declaration non corrisponde alla struttura cartelle
**Soluzione:** 
- Verifica che il file sia in `src/main/java/com/example/servlet/`
- Controlla che la prima riga sia esattamente `package com.example.servlet;`

### Errore: 404 Not Found
```
HTTP Status 404 – Not Found
```
**Causa:** URL mapping sbagliato o servlet non deployato
**Soluzioni:**
- URL corretto: `http://localhost:9292/helloworld/api/hello`
- Verifica che il WAR sia stato deployato in `webapps/`
- Controlla che `@WebServlet("/api/hello")` sia presente

### Errore: NoSuchMethodError
```
java.lang.NoSuchMethodError: jakarta.servlet.http.HttpServlet.init
```
**Causa:** Versioni Maven dependency sbagliate (javax vs jakarta)
**Soluzione:** Usa `jakarta.servlet-api` nel pom.xml, non `javax.servlet-api`

### Errore: Compilation Failed
```
[ERROR] cannot find symbol: class HttpServlet
```
**Causa:** File posizionato fuori da `src/main/java/`
**Soluzioni:**
- Sposta il file in `src/main/java/com/example/servlet/`
- NON mettere mai servlet in `src/main/webapp/`

### Servlet Non Risponde
**Controlli da fare:**
1. File nel posto giusto: `src/main/java/com/example/servlet/HelloWorldServlet.java`
2. Package corretto: `package com.example.servlet;`
3. WAR deployato: Verifica presenza di `webapps/helloworld.war` o `webapps/helloworld/`
4. URL completo: `http://localhost:9292/helloworld/api/hello`
5. Log Tomcat: Controlla `logs/catalina.out` per errori

## Test

Ora che abbiamo un servlet funzionante, compiliamolo e testiamolo:

```bash
mvn package
# Deploy and visit: http://localhost:9292/helloworld/api/hello
```

**Cosa succede:**
1. Maven compila `HelloWorldServlet.java` in `HelloWorldServlet.class`
2. Crea il WAR con la classe compilata in `WEB-INF/classes/com/example/servlet/`
3. Dopo il deploy, Tomcat carica il servlet dalla struttura package corretta
4. L'URL `/api/hello` restituirà il testo "Hello World!"

**Output atteso:** Pagina web con il testo `Hello World!`

### Verifica Deployment
```bash
# Controlla che il servlet sia nel WAR
jar -tf target/helloworld.war | grep HelloWorldServlet
# Output atteso: WEB-INF/classes/com/example/servlet/HelloWorldServlet.class

# Controlla deployment in Tomcat
ls -la webapps/helloworld/WEB-INF/classes/com/example/servlet/
# Output atteso: HelloWorldServlet.class
```