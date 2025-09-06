# Step 3: JSON Response

## Update servlet for JSON

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
        
        // Set JSON content type
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        
        // Build JSON manually
        StringBuilder json = new StringBuilder();
        json.append("{");
        json.append("\"message\": \"Hello World!\",");
        json.append("\"status\": \"success\"");
        json.append("}");
        
        PrintWriter out = response.getWriter();
        out.print(json.toString());
        out.flush();
    }
}
```

## Key changes

- `response.setContentType("application/json")` - Sets JSON content type
- Manual JSON building with `StringBuilder`
- UTF-8 character encoding

## Test output

```json
{
  "message": "Hello World!",
  "status": "success"
}
```