# Step 10: Common Issues

## Build fails

```bash
# Error: JAVA_HOME not set
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# Error: Maven not found
sudo apt install maven

# Clean and rebuild
mvn clean package
```

## Deployment issues

```bash
# Check Tomcat webapps directory
ls -la /usr/local/tomcat/webapps/

# Check if WAR deployed
make status

# Redeploy
make clean deploy
```

## 404 Not Found

Check URL matches servlet mapping:
- Servlet: `@WebServlet("/api/hello")`
- URL: `http://localhost:9292/helloworld/api/hello`
- Format: `http://host:port/app-name/servlet-path`

## 500 Internal Server Error

Check Tomcat logs:
```bash
tail -f logs/localhost_access_log.*.txt
```

Common causes:
- Java compilation errors
- Missing imports
- Exception in servlet code

## CORS errors in browser

Ensure both methods have CORS headers:
```java
// In both doGet() and doOptions()
response.setHeader("Access-Control-Allow-Origin", "*");
```

## Port issues

Default ports:
- Tomcat: 9292 (configured in `.env`)
- Internal Tomcat: 8080
- Check `.env` file for custom ports