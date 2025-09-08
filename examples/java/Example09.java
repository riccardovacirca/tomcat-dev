/* *****************************************************************************
 * Example09 - Interfaces and Abstract Classes
 * Copyright: (C)2018-2025 Riccardo Vacirca. All right reserved.  
 * License: GNU GPL Version 2. See LICENSE
 *
 * Compile: javac Example09.java
 * Run: java Example09
 * ---
 * Drawing circle with radius 5
 * Drawing rectangle 10x20
 * Toyota car engine starts
 * Harley motorcycle engine roars
 * *****************************************************************************
*/

/** Drawable interface */
interface Drawable {
  String draw();
}

/** Circle class implementing Drawable */
class Circle implements Drawable {
  private int radius;

  public Circle(int radius) {
    this.radius = radius;
  }

  @Override
  public String draw() {
    return "Drawing circle with radius " + this.radius;
  }
}

/** Rectangle class implementing Drawable */
class Rectangle implements Drawable {
  private int width, height;

  public Rectangle(int width, int height) {
    this.width = width;
    this.height = height;
  }

  @Override
  public String draw() {
    return "Drawing rectangle " + this.width + "x" + this.height;
  }
}

/** Abstract Vehicle class */
abstract class Vehicle {
  protected String brand;

  public Vehicle(String brand) {
    this.brand = brand;
  }

  public String getBrand() {
    return this.brand;
  }

  public abstract String start();
}

/** Car class extending Vehicle */
class Car extends Vehicle {
  public Car(String brand) {
    super(brand);
  }

  @Override
  public String start() {
    return this.brand + " car engine starts";
  }
}

/** Motorcycle class extending Vehicle */
class Motorcycle extends Vehicle {
  public Motorcycle(String brand) {
    super(brand);
  }

  @Override
  public String start() {
    return this.brand + " motorcycle engine roars";
  }
}

/** InterfaceDemo class */
class InterfaceDemo {
  private String buff = null;

  public InterfaceDemo() {
    Drawable[] shapes = {
      new Circle(5),
      new Rectangle(10, 20)
    };
    
    Vehicle[] vehicles = {
      new Car("Toyota"),
      new Motorcycle("Harley")
    };
    
    this.buff = "";
    for (Drawable shape : shapes) {
      this.buff += shape.draw() + "\n";
    }
    for (Vehicle vehicle : vehicles) {
      this.buff += vehicle.start() + "\n";
    }
    this.buff = this.buff.trim();
  }

  public String toString() {
    return this.buff;
  }
}

public class Example09 {
  public static void main(String[] args) {
    System.out.printf("\n");
    System.out.printf("%s\n", new InterfaceDemo());
    System.out.printf("\n");
  }
}