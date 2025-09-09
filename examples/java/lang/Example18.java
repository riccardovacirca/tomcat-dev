// Simple Event Listener Example

import java.util.ArrayList;
import java.util.List;

// Simple event class
class AppEvent {
  private String eventType;
  private long timestamp;
  public AppEvent(String eventType) {
    this.eventType = eventType;
    this.timestamp = System.currentTimeMillis();
  }
  public String getEventType() { return eventType; }
  public long getTimestamp() { return timestamp; }
}

// Event listener interface
interface AppEventListener {
  void onEvent(AppEvent event);
}

// Simple event listener implementation
class LoggingListener implements AppEventListener {
  private String name;
  public LoggingListener(String name) {
    this.name = name;
  }
  @Override
  public void onEvent(AppEvent event) {
    System.out.printf("[%s] Event: %s at %d%n", 
      name, event.getEventType(), event.getTimestamp());
  }
}

// Event publisher
class EventPublisher {
  private List<AppEventListener> listeners = new ArrayList<>();
  public void addListener(AppEventListener listener) {
    listeners.add(listener);
  }
  public void publishEvent(String eventType) {
    AppEvent event = new AppEvent(eventType);
    for (AppEventListener listener : listeners) {
      listener.onEvent(event);
    }
  }
}

// Main example
public class Example01 {
  public static void main(String[] args) {
    System.out.println("=== Simple Event Listener Example ===\n");
    // Create event publisher
    EventPublisher publisher = new EventPublisher();
    // Add listeners
    publisher.addListener(new LoggingListener("Logger1"));
    publisher.addListener(new LoggingListener("Logger2"));
    // Publish events
    publisher.publishEvent("APPLICATION_STARTED");
    publisher.publishEvent("USER_LOGIN");
    publisher.publishEvent("DATA_PROCESSED");
    publisher.publishEvent("APPLICATION_STOPPED");
  }
}