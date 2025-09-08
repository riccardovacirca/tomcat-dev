/* *****************************************************************************
 * Example08 - Inheritance and Polymorphism
 * Copyright: (C)2018-2025 Riccardo Vacirca. All right reserved.  
 * License: GNU GPL Version 2. See LICENSE
 *
 * Compile: javac Example08.java
 * Run: java Example08
 * ---
 * Buddy barks
 * Whiskers meows
 * Buddy barks
 * Whiskers meows
 * *****************************************************************************
*/

/** Animal base class */
class Animal {
  protected String name;

  public Animal(String name) {
    this.name = name;
  }

  public String speak() {
    return this.name + " makes a sound";
  }
}

/** Dog subclass */
class Dog extends Animal {
  public Dog(String name) {
    super(name);
  }

  @Override
  public String speak() {
    return this.name + " barks";
  }
}

/** Cat subclass */
class Cat extends Animal {
  public Cat(String name) {
    super(name);
  }

  @Override
  public String speak() {
    return this.name + " meows";
  }
}

/** PolymorphismDemo class */
class PolymorphismDemo {
  private String buff = null;

  public PolymorphismDemo() {
    Animal[] animals = {
      new Dog("Buddy"),
      new Cat("Whiskers")
    };
    
    this.buff = "";
    for (Animal animal : animals) {
      this.buff += animal.speak() + "\n";
    }
    this.buff = this.buff.trim();
  }

  public String toString() {
    return this.buff;
  }
}

public class Example08 {
  public static void main(String[] args) {
    System.out.printf("\n");
    System.out.printf("%s\n", new Dog("Buddy").speak());
    System.out.printf("%s\n", new Cat("Whiskers").speak());
    System.out.printf("%s\n", new PolymorphismDemo());
    System.out.printf("\n");
  }
}