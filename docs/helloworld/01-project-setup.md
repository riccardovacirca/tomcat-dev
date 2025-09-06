# Step 1: Project Setup

## Create project structure

```bash
mkdir helloworld
cd helloworld
mkdir -p src/main/java/com/example/servlet
mkdir -p src/main/webapp/WEB-INF
```

## Project structure tree

```
helloworld/
├── pom.xml                    # Maven configuration
├── src/
│   └── main/
│       ├── java/              # Java source code
│       │   └── com/example/servlet/
│       │       └── HelloWorldServlet.java
│       └── webapp/            # Web resources
│           └── WEB-INF/
│               └── web.xml    # Optional web config
└── target/                    # Build output (generated)
    └── helloworld.war         # Final web app package
```

**Spiegazione cartelle:**
- `src/main/java/` - Codice Java sorgente
- `src/main/webapp/` - File web (HTML, CSS, JS)
- `target/` - File compilati e WAR finale
- `pom.xml` - Configurazione Maven

## Cos'è Maven?

Maven è un tool di build per Java che:
- Gestisce le dipendenze automaticamente
- Compila il codice seguendo convenzioni standard
- Crea pacchetti deployabili (WAR, JAR)
- Scarica librerie da repository centrali

## Maven Repository

**URL principale:** https://mvnrepository.com/

**Come aggiungere una dipendenza:**

1. Vai su https://mvnrepository.com/
2. Cerca la libreria (es: "jackson databind")
3. Seleziona la versione
4. Copia il codice XML generato
5. Incollalo nel tuo `<dependencies>` section

**Esempio - aggiungere Jackson per JSON:**
```xml
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
    <version>2.15.2</version>
</dependency>
```

## Create pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>helloworld</artifactId>
    <version>1.0.0</version>
    <packaging>war</packaging>
    
    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <failOnMissingWebXml>false</failOnMissingWebXml>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>jakarta.servlet</groupId>
            <artifactId>jakarta.servlet-api</artifactId>
            <version>6.0.0</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
    
    <build>
        <finalName>helloworld</finalName>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.13.0</version>
                <configuration>
                    <source>17</source>
                    <target>17</target>
                </configuration>
            </plugin>
            
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-war-plugin</artifactId>
                <version>3.4.0</version>
            </plugin>
        </plugins>
    </build>
</project>
```

## Test build

Prima di scrivere codice, verifichiamo che la struttura Maven sia corretta:

```bash
mvn clean package
```

**Cosa fa questo comando:**
- `clean` - Rimuove file di build precedenti
- `package` - Compila e crea il file WAR

**Output atteso:** `target/helloworld.war`

Se il comando fallisce, controlla che Java 17 e Maven siano installati correttamente.