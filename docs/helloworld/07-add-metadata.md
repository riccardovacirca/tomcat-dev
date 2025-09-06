# Step 7: Add Service Metadata

## Enhanced JSON response

```java
@Override
protected void doGet(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
    
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    response.setHeader("Access-Control-Allow-Origin", "*");
    response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    response.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    
    String timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
    
    StringBuilder json = new StringBuilder();
    json.append("{");
    json.append("\"message\": \"Hello World from HelloWorld API!\",");
    json.append("\"timestamp\": \"").append(timestamp).append("\",");
    json.append("\"service\": \"helloworld\",");
    json.append("\"version\": \"1.0.0\",");
    json.append("\"status\": \"success\"");
    json.append("}");
    
    PrintWriter out = response.getWriter();
    out.print(json.toString());
    out.flush();
}
```

## API design principles

- Include service name for identification
- Version number for API evolution
- Status field for error handling
- Descriptive messages

## Output

```json
{
  "message": "Hello World from HelloWorld API!",
  "timestamp": "2024-01-01T12:34:56.789",
  "service": "helloworld",
  "version": "1.0.0",
  "status": "success"
}
```