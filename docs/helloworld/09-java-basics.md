# Step 9: Java Basics for Web Dev

## Package structure

```
src/main/java/com/example/servlet/
                └── HelloWorldServlet.java
```

- `com.example.servlet` = package name
- Must match folder structure
- `package` statement at top of file

## Classes and methods

```java
public class HelloWorldServlet extends HttpServlet {
    // Class inherits from HttpServlet
    
    @Override
    protected void doGet(...) {
        // Method handles GET requests
    }
}
```

## Annotations

```java
@WebServlet("/api/hello")  // Maps URL to servlet
@Override                  // Method overrides parent
```

## String handling

```java
// StringBuilder for efficient string building
StringBuilder json = new StringBuilder();
json.append("{");
json.append("\"key\": \"value\"");
json.append("}");
String result = json.toString();
```

## Exception handling

```java
protected void doGet(...) throws ServletException, IOException {
    // Method declares it might throw these exceptions
    // Tomcat handles them if they occur
}
```

## Java vs JavaScript

| Java | JavaScript |
|------|------------|
| Compiled | Interpreted |
| Strong typing | Dynamic typing |
| Class-based | Prototype-based |
| Runs on server | Runs in browser |