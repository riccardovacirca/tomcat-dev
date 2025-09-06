# Step 6: Handle OPTIONS Request

## Why OPTIONS?

Browsers send OPTIONS requests before actual requests (preflight) to check CORS permissions.

## Add doOptions method

```java
@Override
protected void doOptions(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
    
    // Handle CORS preflight
    response.setHeader("Access-Control-Allow-Origin", "*");
    response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    response.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    response.setStatus(HttpServletResponse.SC_OK);
}
```

## Complete servlet structure

```java
@WebServlet("/api/hello")
public class HelloWorldServlet extends HttpServlet {
    
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        // GET request logic
    }
    
    @Override
    protected void doOptions(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        // CORS preflight logic
    }
}
```

## Key concepts

- HTTP methods: GET, POST, PUT, DELETE, OPTIONS
- Preflight requests happen automatically
- `HttpServletResponse.SC_OK` = status 200