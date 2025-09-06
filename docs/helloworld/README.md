# HelloWorld Tutorial Series

Guida pratica per creare una web app Java con Tomcat. Ogni tutorial è uno step incrementale.

## Tutorial Order

1. **[Project Setup](01-project-setup.md)** - Maven project structure
2. **[Basic Servlet](02-basic-servlet.md)** - First HTTP servlet
3. **[JSON Response](03-json-response.md)** - Return JSON data
4. **[Add Timestamp](04-add-timestamp.md)** - Java time handling
5. **[CORS Headers](05-cors-headers.md)** - Enable cross-origin requests
6. **[Handle OPTIONS](06-handle-options.md)** - CORS preflight requests
7. **[Add Metadata](07-add-metadata.md)** - Service information
8. **[Build Deploy](08-build-deploy.md)** - Makefile automation
9. **[Java Basics](09-java-basics.md)** - Essential Java concepts
10. **[Troubleshooting](10-troubleshooting.md)** - Common problems

## Prerequisites

- Java 17 installed
- Maven installed
- Tomcat development environment running

## Final Result

API endpoint: `GET http://localhost:9292/helloworld/api/hello`

Response:
```json
{
  "message": "Hello World from HelloWorld API!",
  "timestamp": "2024-01-01T12:34:56.789",
  "service": "helloworld",
  "version": "1.0.0",
  "status": "success"
}
```

## Next Steps

After completing this tutorial, explore the Todo app example for more advanced concepts like:
- Database integration
- CRUD operations
- Input validation
- Error handling