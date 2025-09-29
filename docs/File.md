# File

This document describes a file system abstraction layer for Java applications,
providing a clean interface for file operations with support for reading, writing,
appending, metadata access, directory management, permissions, and deletion.

## File System Configuration

The File wrapper provides simplified access to file system operations, abstracting
the complexity of Java's native file APIs (File, Files, Path, etc.) into a unified
interface. All paths are handled as strings for simplicity, with automatic conversion
to appropriate native types internally.

## FileInterface

```java
package org.example.filesystem;

import java.util.List;
import java.util.Map;

public interface FileInterface
{
  void open(String path) throws Exception;
  void close();
  boolean isOpen();

  String read() throws Exception;
  List<String> readLines() throws Exception;
  byte[] readBytes() throws Exception;

  void write(String content) throws Exception;
  void writeLines(List<String> lines) throws Exception;
  void writeBytes(byte[] data) throws Exception;

  void append(String content) throws Exception;
  void appendLines(List<String> lines) throws Exception;

  boolean exists();
  long size() throws Exception;
  long lastModified() throws Exception;
  boolean isDirectory();
  boolean isFile();
  boolean canRead();
  boolean canWrite();
  boolean canExecute();

  void createDirectory() throws Exception;
  void createDirectories() throws Exception;
  List<String> listFiles() throws Exception;
  List<String> listDirectories() throws Exception;
  List<Map<String,Object>> listDetails() throws Exception;

  void setReadable(boolean readable) throws Exception;
  void setWritable(boolean writable) throws Exception;
  void setExecutable(boolean executable) throws Exception;

  void copy(String destination) throws Exception;
  void move(String destination) throws Exception;
  void delete() throws Exception;

  String getAbsolutePath() throws Exception;
  String getParent() throws Exception;
  String getName();
}
```

## File

```java
package org.example.filesystem;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class File implements FileInterface
{
  private String filePath;
  private java.io.File file;
  private Path path;
  private boolean open;

  public File(String path) {
    this.filePath = path;
    this.file = null;
    this.path = null;
    this.open = false;
  }

  // methods...
}
```

### File::open

Opens a file for operations, initializing internal references

```java
@Override
public void open(String path) throws Exception
{
  this.filePath = path;
  this.file = new java.io.File(path);
  this.path = Paths.get(path);
  this.open = true;
}
```

### File::close

Closes the file and releases resources

```java
@Override
public void close()
{
  this.file = null;
  this.path = null;
  this.open = false;
}
```

### File::isOpen

Returns true if the file is open for operations

```java
@Override
public boolean isOpen()
{
  return this.open && this.file != null;
}
```

### File::read

Reads the entire file content as a string

```java
@Override
public String read() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.exists()) {
    throw new Exception("File does not exist: " + filePath);
  }

  return new String(Files.readAllBytes(path));
}
```

### File::readLines

Reads the file content as a list of lines

```java
@Override
public List<String> readLines() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.exists()) {
    throw new Exception("File does not exist: " + filePath);
  }

  return Files.readAllLines(path);
}
```

### File::readBytes

Reads the file content as raw bytes

```java
@Override
public byte[] readBytes() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.exists()) {
    throw new Exception("File does not exist: " + filePath);
  }

  return Files.readAllBytes(path);
}
```

### File::write

Writes content to the file, overwriting existing content

```java
@Override
public void write(String content) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  Files.write(path, content.getBytes());
}
```

### File::writeLines

Writes a list of lines to the file

```java
@Override
public void writeLines(List<String> lines) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  Files.write(path, lines);
}
```

### File::writeBytes

Writes raw bytes to the file

```java
@Override
public void writeBytes(byte[] data) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  Files.write(path, data);
}
```

### File::append

Appends content to the end of the file

```java
@Override
public void append(String content) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  try (BufferedWriter writer = new BufferedWriter(new FileWriter(file, true))) {
    writer.write(content);
  }
}
```

### File::appendLines

Appends lines to the end of the file

```java
@Override
public void appendLines(List<String> lines) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  try (BufferedWriter writer = new BufferedWriter(new FileWriter(file, true))) {
    for (String line : lines) {
      writer.write(line);
      writer.newLine();
    }
  }
}
```

### File::exists

Returns true if the file or directory exists

```java
@Override
public boolean exists()
{
  return isOpen() && file.exists();
}
```

### File::size

Returns the file size in bytes

```java
@Override
public long size() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.exists()) {
    throw new Exception("File does not exist: " + filePath);
  }

  return Files.size(path);
}
```

### File::lastModified

Returns the last modification timestamp

```java
@Override
public long lastModified() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.exists()) {
    throw new Exception("File does not exist: " + filePath);
  }

  return file.lastModified();
}
```

### File::isDirectory

Returns true if the path is a directory

```java
@Override
public boolean isDirectory()
{
  return isOpen() && file.isDirectory();
}
```

### File::isFile

Returns true if the path is a regular file

```java
@Override
public boolean isFile()
{
  return isOpen() && file.isFile();
}
```

### File::canRead

Returns true if the file is readable

```java
@Override
public boolean canRead()
{
  return isOpen() && file.canRead();
}
```

### File::canWrite

Returns true if the file is writable

```java
@Override
public boolean canWrite()
{
  return isOpen() && file.canWrite();
}
```

### File::canExecute

Returns true if the file is executable

```java
@Override
public boolean canExecute()
{
  return isOpen() && file.canExecute();
}
```

### File::createDirectory

Creates a single directory

```java
@Override
public void createDirectory() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  Files.createDirectory(path);
}
```

### File::createDirectories

Creates directories including parent directories

```java
@Override
public void createDirectories() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  Files.createDirectories(path);
}
```

### File::listFiles

Returns a list of file names in the directory

```java
@Override
public List<String> listFiles() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.isDirectory()) {
    throw new Exception("Not a directory: " + filePath);
  }

  return Files.list(path)
    .filter(Files::isRegularFile)
    .map(p -> p.getFileName().toString())
    .collect(Collectors.toList());
}
```

### File::listDirectories

Returns a list of subdirectory names

```java
@Override
public List<String> listDirectories() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.isDirectory()) {
    throw new Exception("Not a directory: " + filePath);
  }

  return Files.list(path)
    .filter(Files::isDirectory)
    .map(p -> p.getFileName().toString())
    .collect(Collectors.toList());
}
```

### File::listDetails

Returns detailed information about directory contents

```java
@Override
public List<Map<String,Object>> listDetails() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.isDirectory()) {
    throw new Exception("Not a directory: " + filePath);
  }

  List<Map<String,Object>> details = new ArrayList<>();

  Files.list(path).forEach(p -> {
    Map<String,Object> info = new HashMap<>();
    java.io.File f = p.toFile();
    info.put("name", f.getName());
    info.put("path", p.toString());
    info.put("isFile", f.isFile());
    info.put("isDirectory", f.isDirectory());
    info.put("size", f.length());
    info.put("lastModified", f.lastModified());
    info.put("canRead", f.canRead());
    info.put("canWrite", f.canWrite());
    info.put("canExecute", f.canExecute());
    details.add(info);
  });

  return details;
}
```

### File::setReadable

Sets the readable permission

```java
@Override
public void setReadable(boolean readable) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  if (!file.setReadable(readable)) {
    throw new Exception("Failed to set readable permission");
  }
}
```

### File::setWritable

Sets the writable permission

```java
@Override
public void setWritable(boolean writable) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  if (!file.setWritable(writable)) {
    throw new Exception("Failed to set writable permission");
  }
}
```

### File::setExecutable

Sets the executable permission

```java
@Override
public void setExecutable(boolean executable) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  if (!file.setExecutable(executable)) {
    throw new Exception("Failed to set executable permission");
  }
}
```

### File::copy

Copies the file to a destination

```java
@Override
public void copy(String destination) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.exists()) {
    throw new Exception("Source file does not exist: " + filePath);
  }

  Path destPath = Paths.get(destination);
  Files.copy(path, destPath, StandardCopyOption.REPLACE_EXISTING);
}
```

### File::move

Moves the file to a destination

```java
@Override
public void move(String destination) throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.exists()) {
    throw new Exception("Source file does not exist: " + filePath);
  }

  Path destPath = Paths.get(destination);
  Files.move(path, destPath, StandardCopyOption.REPLACE_EXISTING);

  // Update internal references to new location
  this.filePath = destination;
  this.file = new java.io.File(destination);
  this.path = destPath;
}
```

### File::delete

Deletes the file or directory

```java
@Override
public void delete() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }
  if (!file.exists()) {
    throw new Exception("File does not exist: " + filePath);
  }

  Files.delete(path);
}
```

### File::getAbsolutePath

Returns the absolute path of the file

```java
@Override
public String getAbsolutePath() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  return file.getAbsolutePath();
}
```

### File::getParent

Returns the parent directory path

```java
@Override
public String getParent() throws Exception
{
  if (!isOpen()) {
    throw new Exception("File not open");
  }

  return file.getParent();
}
```

### File::getName

Returns the file name

```java
@Override
public String getName()
{
  return isOpen() ? file.getName() : null;
}
```

### File Usage Example

```java
import org.example.filesystem.File;

import java.util.List;
import java.util.Map;
import java.util.Arrays;

// Initialize file wrapper
File file = new File("/path/to/document.txt");

try {
    // Open file for operations
    file.open("/path/to/document.txt");

    if (file.isOpen()) {
        // Check if file exists
        if (!file.exists()) {
            // Create new file with content
            file.write("Hello, World!\nThis is a test file.");
            System.out.println("File created and written");
        }

        // Read entire file
        String content = file.read();
        System.out.println("File content: " + content);

        // Read as lines
        List<String> lines = file.readLines();
        System.out.println("Number of lines: " + lines.size());

        // Append content
        file.append("\nAppended line");

        // Append multiple lines
        file.appendLines(Arrays.asList("Line 1", "Line 2", "Line 3"));

        // Get file metadata
        System.out.println("File size: " + file.size() + " bytes");
        System.out.println("Last modified: " + file.lastModified());
        System.out.println("Can read: " + file.canRead());
        System.out.println("Can write: " + file.canWrite());

        // Copy file
        file.copy("/path/to/backup.txt");
        System.out.println("File copied to backup.txt");

        // Get absolute path
        System.out.println("Absolute path: " + file.getAbsolutePath());
    }

} catch (Exception e) {
    e.printStackTrace();
} finally {
    // Close file
    file.close();
}
```

## DirectoryIteratorInterface

```java
package org.example.filesystem;

import java.util.Map;

public interface DirectoryIteratorInterface extends AutoCloseable
{
  boolean next() throws Exception;
  String getName() throws Exception;
  Map<String,Object> getDetails() throws Exception;
  void close();
}
```

## DirectoryIterator

```java
package org.example.filesystem;

import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class DirectoryIterator implements DirectoryIteratorInterface {
  private final DirectoryStream<Path> stream;
  private final Iterator<Path> iterator;
  private Path currentPath;

  public DirectoryIterator(String directoryPath) throws IOException {
    Path dir = Paths.get(directoryPath);
    this.stream = Files.newDirectoryStream(dir);
    this.iterator = stream.iterator();
    this.currentPath = null;
  }

  // methods...
}
```

### DirectoryIterator::next

Moves to the next file or directory

```java
@Override
public boolean next() throws Exception {
  if (iterator.hasNext()) {
    currentPath = iterator.next();
    return true;
  }
  return false;
}
```

### DirectoryIterator::getName

Returns the name of the current file or directory

```java
@Override
public String getName() throws Exception {
  if (currentPath == null) {
    throw new Exception("No current file");
  }
  return currentPath.getFileName().toString();
}
```

### DirectoryIterator::getDetails

Returns detailed information about the current file or directory

```java
@Override
public Map<String,Object> getDetails() throws Exception {
  if (currentPath == null) {
    throw new Exception("No current file");
  }

  Map<String,Object> details = new HashMap<>();
  java.io.File file = currentPath.toFile();

  details.put("name", file.getName());
  details.put("path", currentPath.toString());
  details.put("absolutePath", file.getAbsolutePath());
  details.put("isFile", file.isFile());
  details.put("isDirectory", file.isDirectory());
  details.put("size", file.length());
  details.put("lastModified", file.lastModified());
  details.put("canRead", file.canRead());
  details.put("canWrite", file.canWrite());
  details.put("canExecute", file.canExecute());

  return details;
}
```

### DirectoryIterator::close

Closes the directory iterator and releases resources

```java
@Override
public void close() {
  try {
    if (stream != null) stream.close();
  } catch (IOException e) {}
}
```

### DirectoryIterator Usage Example

```java
import org.example.filesystem.File;
import org.example.filesystem.DirectoryIterator;
import java.util.Map;

// Initialize file wrapper for directory operations
File dir = new File("/path/to/directory");

try {
    // Open directory
    dir.open("/path/to/directory");

    if (dir.isOpen() && dir.isDirectory()) {
        // Method 1: List all files at once
        System.out.println("Files in directory:");
        for (String filename : dir.listFiles()) {
            System.out.println("  File: " + filename);
        }

        System.out.println("Subdirectories:");
        for (String dirname : dir.listDirectories()) {
            System.out.println("  Directory: " + dirname);
        }

        // Method 2: Get detailed listing
        System.out.println("\nDetailed listing:");
        for (Map<String,Object> detail : dir.listDetails()) {
            System.out.println("  " + detail.get("name") +
                             " (Size: " + detail.get("size") +
                             ", Type: " + (Boolean.TRUE.equals(detail.get("isDirectory")) ? "DIR" : "FILE") + ")");
        }

        // Method 3: Iterate through directory (for large directories)
        DirectoryIterator iterator = new DirectoryIterator("/path/to/directory");

        try {
            System.out.println("\nIterating through directory:");
            while (iterator.next()) {
                // Get current file name
                String name = iterator.getName();

                // Get detailed information
                Map<String,Object> fileInfo = iterator.getDetails();

                System.out.printf("Processing: %s (%s, %d bytes)%n",
                    name,
                    Boolean.TRUE.equals(fileInfo.get("isDirectory")) ? "DIR" : "FILE",
                    (Long) fileInfo.get("size"));

                // Example: Process files in batches
                if ((Long) fileInfo.get("size") > 1000000) {
                    System.out.println("  Large file detected!");
                }
            }

        } finally {
            iterator.close();
        }

        // Directory management
        File newDir = new File("/path/to/new/directory");
        newDir.open("/path/to/new/directory");

        if (!newDir.exists()) {
            newDir.createDirectories();
            System.out.println("Created directory structure");
        }

        newDir.close();
    }

} catch (Exception e) {
    e.printStackTrace();
} finally {
    dir.close();
}
```

## Build library

### Create new library project

```bash
make lib name=filesystem-lib
cd projects/filesystem-lib
```

### Set groupId

```bash
cd src/main/java
mv com/example org/example
```

### Rename class packages

```java
// From:  package com.example.filesystem;
// to:    package org.example.filesystem;
```

### Add class and interface files to the project

```
projects/filesystem-lib/
├── pom.xml
└── src/
    └── main/
        └── java/
            └── org/
                └── example/
                    └── filesystem/
                        ├── FileInterface.java
                        ├── File.java
                        ├── DirectoryIteratorInterface.java
                        └── DirectoryIterator.java
```

### Build library

```bash
make build
```

### Install locally

```bash
make install
```

## Distribute

### Case 1: Complete project transfer

```bash
# 1. Transfer the entire directory
scp -r projects/filesystem-lib/ destination:/path/to/projects/

# 2. In the destination container
cd /path/to/projects/filesystem-lib
mvn install
```

### Case 2: JAR-only transfer

```bash
# 1. Transfer only the JAR
scp projects/filesystem-lib/target/filesystem-lib-1.0-SNAPSHOT.jar destination:/tmp/

# 2. In the destination container
mvn install:install-file \
  -Dfile=/tmp/filesystem-lib-1.0-SNAPSHOT.jar \
  -DgroupId=org.example \
  -DartifactId=filesystem-lib \
  -Dversion=1.0-SNAPSHOT \
  -Dpackaging=jar
```

### Case 3: Direct copy to WEB-INF/lib

```bash
# 1. Transfer the JAR to the webapp
scp projects/filesystem-lib/target/filesystem-lib-1.0-SNAPSHOT.jar destination:/webapp/WEB-INF/lib/

# 2. No dependency needed in pom.xml
# 3. Restart Tomcat
```

## Using in the application

### Configure webapp pom.xml (Cases 1 and 2)

```xml
<dependency>
  <groupId>org.example</groupId>
  <artifactId>filesystem-lib</artifactId>
  <version>1.0-SNAPSHOT</version>
</dependency>
```

### Import in code

```java
import org.example.filesystem.File;
import org.example.filesystem.DirectoryIterator;
import java.util.List;
import java.util.Map;

File file = new File("/path/to/file.txt");
file.open("/path/to/file.txt");
String content = file.read();
file.close();
```

---
@2020-2025 Riccardo Vacirca - All right reserved.