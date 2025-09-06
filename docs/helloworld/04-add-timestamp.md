# Step 4: Add Timestamp

## Import Java time classes

```java
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
```

## Update doGet method

```java
@Override
protected void doGet(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
    
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    
    // Get current timestamp
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

## Java time concepts

- `LocalDateTime.now()` - Current date/time
- `DateTimeFormatter.ISO_LOCAL_DATE_TIME` - ISO format (2024-01-01T12:00:00)
- String concatenation with `.append()`

## Test output

```json
{
  "message": "Hello World!",
  "timestamp": "2024-01-01T12:34:56.789",
  "status": "success"
}
```