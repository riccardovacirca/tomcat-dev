# HelloWorld API

A simple HelloWorld API webapp built with Jakarta Servlets.

## Features

- ✅ Simple JSON response with timestamp
- ✅ CORS enabled for development  
- ✅ No database dependencies
- ✅ Ready to use out of the box

## Structure

```
src/
├── main/
│   ├── java/com/example/servlet/
│   │   └── HelloWorldServlet.java    # Main servlet
│   └── webapp/
│       ├── WEB-INF/web.xml          # Web configuration
│       └── index.html               # Documentation
└── target/                          # Build output
```

## API Endpoint

### GET /api/hello
Returns a JSON hello world message with timestamp.

**Response:**
```json
{
  "message": "Hello World from HelloWorld API!",
  "timestamp": "2025-09-02T17:30:00",
  "service": "helloworld", 
  "version": "1.0.0",
  "status": "success"
}
```

## Build and Deploy

```bash
# Build
make build

# Deploy to Tomcat
make deploy

# Check status
make status

# Clean
make clean
```

## Usage

```bash
# Test endpoint
curl http://localhost:9292/helloworld/api/hello

# View documentation
open http://localhost:9292/helloworld/
```

Perfect for learning servlet basics and testing deployment workflows!