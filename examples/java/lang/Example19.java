
// Lambda Expressions Example - Simplified Version

public class Example19 {
  public static void main(String[] args) {
    System.out.println("=== Lambda Expressions Example ===\n");
    // Traditional anonymous inner class approach
    Thread traditionalWorker = new Thread(new Runnable() {
      @Override
      public void run() {
        System.out.println("Traditional worker: started and finished");
      }
    });
    // Lambda expression approach - much more concise
    Thread lambdaWorker = new Thread(() -> {
      for (int i = 1; i <= 3; i++) {
        System.out.println("Lambda worker dice: passo " + i);
        try {
          Thread.sleep(1000);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          break;
        }
      }
      System.out.println("Lambda worker terminato");
    });
    // Execute both threads
    traditionalWorker.start();
    lambdaWorker.start();
    // Wait for completion
    try {
      traditionalWorker.join();
      lambdaWorker.join();
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    }
    System.out.println("\n=== Lambda with Functional Interfaces ===\n");
    // Simple lambda operations
    MathOperation addition = (a, b) -> a + b;
    MathOperation multiplication = (a, b) -> a * b;
    System.out.println("Addition: 5 + 3 = " + addition.operate(5, 3));
    System.out.println("Multiplication: 5 * 3 = " + multiplication.operate(5, 3));
    // Multi-statement lambda
    StringProcessor processor = (str) -> {
      String result = str.toUpperCase().trim();
      return result + "!";
    };
    System.out.println("Processed: " + processor.process("  hello world  "));
    System.out.println("\nMain terminato");
  }

  // Functional interfaces for lambda examples
  @FunctionalInterface
  interface MathOperation {
    int operate(int a, int b);
  }

  @FunctionalInterface
  interface StringProcessor {
    String process(String input);
  }
}