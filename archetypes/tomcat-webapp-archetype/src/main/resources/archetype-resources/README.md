# ${artifactId}

Maven web application generated for Tomcat development environment.

## Quick Start

### Build Commands

```bash
# Clean build artifacts
make clean

# Build the application
make build

# Deploy to Tomcat
make deploy

# Check deployment status
make status
```

### Testing

After deployment, access your application at:
- http://localhost:9292/${artifactId}/

API endpoint:
- http://localhost:9292/${artifactId}/api/hello

### Project Structure

```
${artifactId}/
├── pom.xml                          # Maven configuration
├── Makefile                         # Build and deploy commands
├── README.md                        # This file
├── src/
│   └── main/
│       ├── java/
│       │   └── ${package}/servlet/
│       │       └── HelloServlet.java # Sample servlet
│       └── webapp/
│           ├── index.html           # Main page
│           └── WEB-INF/
│               └── web.xml          # Web app configuration
└── target/
    └── ${artifactId}.war           # Generated WAR file
```

### Development Workflow

1. Modify your servlets in `src/main/java/`
2. Update JSP/HTML files in `src/main/webapp/`
3. Run `make build` to compile
4. Run `make deploy` to deploy to Tomcat
5. Test at http://localhost:9292/${artifactId}/

### Features

- ✅ Modern Maven configuration (Java 17, Jakarta EE)
- ✅ Sample servlet with JSON API
- ✅ CORS enabled for development
- ✅ Ready for Tomcat deployment
- ✅ Makefile for easy build/deploy

---

Generated with Tomcat Development Environment