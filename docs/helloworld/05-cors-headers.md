# Step 5: CORS Headers

## What is CORS?

CORS (Cross-Origin Resource Sharing) allows browsers to access your API from different domains/ports.

## Add CORS headers

```java
@Override
protected void doGet(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
    
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    
    // Enable CORS
    response.setHeader("Access-Control-Allow-Origin", "*");
    response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    response.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    
    String timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
    
    StringBuilder json = new StringBuilder();
    json.append("{");
    json.append("\"message\": \"Hello World!\",");
    json.append("\"timestamp\": \"").append(timestamp).append("\",");
    json.append("\"status\": \"success\"");
    json.append("}");
    
    PrintWriter out = response.getWriter();
    out.print(json.toString());
    out.flush();
}
```

## CORS headers explained

- `Access-Control-Allow-Origin: *` - Allow all origins
- `Access-Control-Allow-Methods` - Allowed HTTP methods
- `Access-Control-Allow-Headers` - Allowed request headers

## Why needed?

Without CORS, browsers block requests from different domains (localhost:3000 → localhost:9292)