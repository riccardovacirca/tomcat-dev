# Java Tutorial

## Table of Contents

- [Simple HelloWorld Message](#simple-helloworld-message)
- [Primitive Types and Wrappers](#primitive-types-and-wrappers)
- [Arrays and Arrays Utilities](#arrays-and-arrays-utilities)
- [Wrapper Class Methods](#wrapper-class-methods)
- [Code Blocks](#code-blocks)

## Simple HelloWorld Message

Source file: `examples/java/Example01.java`

### Class Declaration

```java
class HelloWorld
{
  private String buff = null;
```

Defines a class named HelloWorld. The class is a template for creating objects.

### Private Attribute

```java
private String buff = null;
```

Declares a private instance variable that stores the message. Only methods of this class can access it.

### Constructor

```java
public HelloWorld() {
  this.buff = "Hello, World!";
}
```

The constructor is called automatically when creating a new object with `new`. It initializes the buff attribute.

### toString() Method

```java
public String toString() {
  return this.buff;
}
```

Override of the toString() method inherited from Object. Returns the string representation of the object.

### Main Class

```java
public class Example01
{
```

The public class containing the main method. The name must match the filename.

### Main Method

```java
public static void main(String[] args) {
```

Entry point of the program. The JVM looks for this method to start execution.

### Object Creation and Output

```java
System.out.printf("\n");
System.out.printf("%s\n", new HelloWorld());
System.out.printf("\n");
```

Creates a new HelloWorld object and prints it. The printf automatically calls toString() on the object.

### Complete HelloWorld Example

```java
/** HelloWorld class */
class HelloWorld {
  private String buff = null;
  
  public HelloWorld() {
    this.buff = "Hello, World!";
  }
  
  public String toString() {
    return this.buff;
  }
}

public class Example01 {
  public static void main(String[] args) {
    System.out.printf("\n");
    System.out.printf("%s\n", new HelloWorld());
    System.out.printf("\n");
  }
}
```

Complete program demonstrating basic class creation, object instantiation, and output.

[↑ Back to Contents](#table-of-contents)

## Primitive Types and Wrappers

Source file: `examples/java/Example02.java`

### CharType Class Declaration

```java
class CharType
{
  private String buff = null;
```

Defines a class that demonstrates character type usage. Uses a buffer to store formatted output.

### CharType Constructor - Primitive Variables

```java
char x, y, z;
x = 'A';
y = 'B';
z = 'C';
this.buff = String.format("x = %c, y = %c, z = %c", x, y, z);
```

Creates primitive char variables and assigns character literal values. Uses direct character assignment.

### CharType Constructor - Wrapper Variables

```java
Character x = 'A', y = 'B', z = 'C';
this.buff += String.format("x = %c, y = %c, z = %c", x, y, z);
```

Creates Character wrapper objects with character literals. Demonstrates autoboxing from char to Character.

### IntType Class - Primitive and Wrapper

```java
class IntType {
  private String buff = null;

  public IntType() {
    int x, y, z;
    x = 1;
    y = 2;
    z = 3;
    this.buff = String.format("x = %d, y = %d, z = %d", x, y, z);
    
    this.buff += "\n";
    Integer a = 1, b = 2, c = 3;
    this.buff += String.format("x = %d, y = %d, z = %d", a, b, c);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates integer type usage with both primitive int and wrapper Integer types.

### DoubleType Class - Primitive and Wrapper

```java
class DoubleType {
  private String buff = null;

  public DoubleType() {
    double x, y, z;
    x = 1.1;
    y = 2.2;
    z = 3.3;
    this.buff = String.format("x = %.1f, y = %.1f, z = %.1f", x, y, z);
    
    this.buff += "\n";
    Double a = 1.1, b = 2.2, c = 3.3;
    this.buff += String.format("x = %.1f, y = %.1f, z = %.1f", a, b, c);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates double type usage with primitive double and wrapper Double types.

### Expected Output

```
x = A, y = B, z = C
x = A, y = B, z = C
x = 1, y = 2, z = 3
x = 1, y = 2, z = 3
x = 1.1, y = 2.2, z = 3.3
x = 1.1, y = 2.2, z = 3.3
```

Shows the output comparing primitive types with their corresponding wrapper classes.

[↑ Back to Contents](#table-of-contents)

## Arrays and Arrays Utilities

Source file: `examples/java/Example03.java`

### CharArray Class - Primitive Arrays

```java
class CharArray {
  private String buff = null;

  public CharArray() {
    char[] x = new char[3];
    x[0] = 'A';
    x[1] = 'B';
    x[2] = 'C';
    this.buff = String.format("[%c, %c, %c]", x[0], x[1], x[2]);
    
    this.buff += "\n";
    Character[] y = {'A', 'B', 'C'};
    this.buff += String.format("[%c, %c, %c]", y[0], y[1], y[2]);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates character array creation with explicit size and initialization syntax.

### IntArray Class - Array Creation

```java
class IntArray {
  private String buff = null;

  public IntArray() {
    int[] x = new int[3];
    x[0] = 10;
    x[1] = 20;
    x[2] = 30;
    this.buff = String.format("[%d, %d, %d]", x[0], x[1], x[2]);
    
    this.buff += "\n";
    Integer[] y = {10, 20, 30};
    this.buff += String.format("[%d, %d, %d]", y[0], y[1], y[2]);
  }

  public String toString() {
    return this.buff;
  }
}
```

Creates integer arrays using both new operator and initialization syntax.

### ArraysUtils Class - Utility Methods

```java
class ArraysUtils {
  private String buff = null;

  public ArraysUtils() {
    int[] x = {30, 10, 20};
    this.buff = "Original: " + java.util.Arrays.toString(x) + "\n";
    
    java.util.Arrays.sort(x);
    this.buff += "Sorted: " + java.util.Arrays.toString(x) + "\n";
    
    int found = java.util.Arrays.binarySearch(x, 20);
    this.buff += "Index of 20: " + found + "\n";
    
    int[] y = java.util.Arrays.copyOf(x, 5);
    this.buff += "Copy extended: " + java.util.Arrays.toString(y);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates Arrays utility methods: toString(), sort(), binarySearch(), copyOf().

### ArraysComparison Class - Comparison Methods

```java
class ArraysComparison {
  private String buff = null;

  public ArraysComparison() {
    int[] x = {1, 2, 3};
    int[] y = {1, 2, 3};
    int[] z = {3, 2, 1};
    
    this.buff = "x equals y: " + java.util.Arrays.equals(x, y) + "\n";
    this.buff += "x equals z: " + java.util.Arrays.equals(x, z) + "\n";
    
    java.util.Arrays.fill(z, 0);
    this.buff += "z after fill: " + java.util.Arrays.toString(z);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates array comparison with equals() and array modification with fill().

### Expected Arrays Output

```
[A, B, C]
[A, B, C]
[10, 20, 30]
[10, 20, 30]
[1.1, 2.2, 3.3]
[1.1, 2.2, 3.3]
Original: [30, 10, 20]
Sorted: [10, 20, 30]
Index of 20: 1
Copy extended: [10, 20, 30, 0, 0]
x equals y: true
x equals z: false
z after fill: [0, 0, 0]
```

Complete output showing array operations and utility method results.

[↑ Back to Contents](#table-of-contents)

## Wrapper Class Methods

Source file: `examples/java/Example04.java`

### CharacterCreation Class

```java
class CharacterCreation {
  private String buff = null;

  public CharacterCreation() {
    Character x = Character.valueOf('A');
    char y = x.charValue();
    String z = x.toString();
    this.buff = String.format("valueOf: %c, charValue: %c, toString: %s",
                              x, y, z);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates Character wrapper using valueOf() factory method, charValue(), and toString().

### CharacterComparison Class

```java
class CharacterComparison {
  private String buff = null;

  public CharacterComparison() {
    Character x = 'A';
    Character y = 'A';
    boolean eq = x.equals(y);
    int cmp1 = Character.compare('A', 'A');
    int cmp2 = x.compareTo(y);
    this.buff = String.format("equals: %b, compare: %d, compareTo: %d",
                              eq, cmp1, cmp2);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates character equality with equals(), static compare(), and instance compareTo().

### CharacterValidation Class

```java
class CharacterValidation {
  private String buff = null;

  public CharacterValidation() {
    char x = 'A';
    boolean digit = Character.isDigit(x);
    boolean letter = Character.isLetter(x);
    this.buff = String.format("isDigit: %b, isLetter: %b", digit, letter);
  }

  public String toString() {
    return this.buff;
  }
}
```

Tests character type using static methods isDigit() and isLetter().

### CharacterTransformation Class

```java
class CharacterTransformation {
  private String buff = null;

  public CharacterTransformation() {
    char x = 'A';
    char lower = Character.toLowerCase(x);
    char upper = Character.toUpperCase(x);
    this.buff = String.format("toLowerCase: %c, toUpperCase: %c", lower, upper);
  }

  public String toString() {
    return this.buff;
  }
}
```

Converts character case using static methods toLowerCase() and toUpperCase().

### IntegerCreation Class

```java
class IntegerCreation {
  private String buff = null;

  public IntegerCreation() {
    Integer x = Integer.valueOf(42);
    int y = x.intValue();
    String z = x.toString();
    this.buff = String.format("valueOf: %d, intValue: %d, toString: %s",
                              x, y, z);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates Integer wrapper creation and primitive conversion methods.

### DoubleCreation Class

```java
class DoubleCreation {
  private String buff = null;

  public DoubleCreation() {
    Double x = Double.valueOf(3.14);
    double y = x.doubleValue();
    String z = x.toString();
    this.buff = String.format("valueOf: %.2f, doubleValue: %.2f, toString: %s",
                              x, y, z);
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates Double wrapper creation and primitive conversion methods.

### Expected Wrapper Methods Output

```
valueOf: A, charValue: A, toString: A
equals: true, compare: 0, compareTo: 0
isDigit: false, isLetter: true
toLowerCase: a, toUpperCase: A
valueOf: 42, intValue: 42, toString: 42
equals: true, compare: 0, compareTo: 0
valueOf: 3.14, doubleValue: 3.14, toString: 3.14
equals: true, compare: 0, compareTo: 0
```

Complete output showing wrapper class method functionality.

[↑ Back to Contents](#table-of-contents)

## Code Blocks

Source file: `examples/java/Example05.java`

### ClassBlock Class - Static Block

```java
class ClassBlock {
  private String buff = null;

  static {
    System.out.printf("Static block executed\n");
  }

  public ClassBlock() {
    this.buff = "Static block executed";
  }

  public String toString() {
    return this.buff;
  }
}
```

Static block executes once when the class is first loaded by the JVM. Runs before any instance creation.

### InstanceBlock Class - Instance Block

```java
class InstanceBlock {
  private String buff = null;

  {
    this.buff = "Instance block executed";
  }

  public InstanceBlock() {
    // Constructor called after instance block
  }

  public String toString() {
    return this.buff;
  }
}
```

Instance block executes every time a new object is created. Runs before the constructor code.

### ConstructorBlock Class - Execution Order

```java
class ConstructorBlock {
  private String buff = null;

  {
    this.buff = "Instance block executed\n";
  }

  public ConstructorBlock() {
    this.buff += "Constructor called";
  }

  public String toString() {
    return this.buff;
  }
}
```

Shows the execution order of instance block and constructor. Instance block runs first.

### MethodBlock Class - Local Blocks

```java
class MethodBlock {
  private String buff = null;

  public MethodBlock() {
    this.executeMethodBlock();
  }

  private void executeMethodBlock() {
    {
      String temp = "Method block executed";
      this.buff = temp;
    }
  }

  public String toString() {
    return this.buff;
  }
}
```

Method contains a local block with its own scope. Variables declared inside are only accessible within it.

### LocalBlock Class - Variable Scope

```java
class LocalBlock {
  private String buff = null;

  public LocalBlock() {
    String outer = "Local";
    {
      String inner = " block executed";
      this.buff = outer + inner;
    }
  }

  public String toString() {
    return this.buff;
  }
}
```

Demonstrates variable scope in local blocks. Outer variables are accessible inside blocks.

### Expected Code Blocks Output

```
Static block executed
Static block executed
Instance block executed
Instance block executed
Constructor called
Method block executed
Local block executed
```

Shows execution order: static → instance → constructor → method blocks.

[↑ Back to Contents](#table-of-contents)

---

Copyright: (C)2018-2025 Riccardo Vacirca. All right reserved.  
License: GNU GPL Version 2. See LICENSE