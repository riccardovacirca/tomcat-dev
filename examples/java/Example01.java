/* *****************************************************************************
 * Example01 - Simple HelloWorld message
 * Copyright: (C)2018-2025 Riccardo Vacirca. All right reserved.  
 * License: GNU GPL Version 2. See LICENSE
 *
 * Compile: javac Example01.java
 * Run: java Example01
 * ---
 * Hello, World!
 * *****************************************************************************
*/

/** HelloWorld class
*/
class HelloWorld
{
  // Private instance attribute
  private String buff = null;
  
  // Class constructor
  public HelloWorld() {
    this.buff = "Hello, World!";
  }
  
  // Override inherited toString method
  public String toString() {
    return this.buff;
  }
}

public class Example01
{
  public static void main(String[] args) {
    // Output instructions
    System.out.printf("\n");
    System.out.printf("%s\n", new HelloWorld());
    System.out.printf("\n");
  }
}
