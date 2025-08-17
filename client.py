import socket
import numpy as np
import time
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation

ESP_IP = "192.168.4.1"
ESP_PORT = 80
BUFFER_SIZE = 16384  # Number of 16-bit integers
PACKET_SIZE = BUFFER_SIZE * 2  # 32768 bytes (16384 * 2)

# Set up the plot
plt.ion()  # Interactive mode on
fig, ax = plt.subplots(figsize=(12, 6))
line, = ax.plot([], [])
ax.set_ylim(0, 4096)  # Fixed y-axis range
ax.set_xlim(0, BUFFER_SIZE)
ax.set_xlabel('Sample Index')
ax.set_ylabel('Value')
ax.set_title('Real-time Data from ESP32')
plt.grid(True)

def receive_data():
    sock = None
    try:
        # Create and connect socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5.0)
        sock.connect((ESP_IP, ESP_PORT))
        
        # Send minimal request (some servers need this)
        sock.sendall(b"GET / HTTP/1.0\r\n\r\n")
        
        print(f"Connected to ESP32. Waiting for {BUFFER_SIZE} integers...")
        
        while True:
            try:
                start_time = time.time()
                
                # Receive exactly PACKET_SIZE bytes
                received_bytes = 0
                chunks = []
                
                while received_bytes < PACKET_SIZE:
                    remaining = PACKET_SIZE - received_bytes
                    chunk = sock.recv(min(remaining, 4096))
                    if not chunk:
                        raise ConnectionError("Connection closed by ESP32")
                    chunks.append(chunk)
                    received_bytes += len(chunk)
                
                # Process received data
                buffer = b''.join(chunks)
                data = np.frombuffer(buffer, dtype=np.uint16)
                
                # Update the plot
                line.set_xdata(np.arange(len(data)))
                line.set_ydata(data)
                fig.canvas.draw()
                fig.canvas.flush_events()
                
                transfer_time = time.time() - start_time
                bandwidth = (PACKET_SIZE / (1024 * 1024)) / transfer_time  # MB/s
                
                print(f"Received {len(data)} integers in {transfer_time:.3f}s ({bandwidth:.2f} MB/s)")
                print("First 10 values:", data[:10])
                print("Last 10 values:", data[-10:])
                print("-----")
                
            except KeyboardInterrupt:
                print("\nStopped by user")
                break
            except Exception as e:
                print(f"Error: {e}")
                break
                
    finally:
        if sock:
            sock.close()
        print("Connection closed")
        plt.ioff()  # Turn off interactive mode
        plt.show()  # Keep the plot window open

if __name__ == "__main__":
    receive_data()