const url = `ws://localhost:${process.env.DREAM_PORT}/websocket`;
const socket = new WebSocket(url);

// The server sends the reply but does not close the TCP connection, so exit
// explicitly once the message has been written.
setTimeout(() => {
  console.error("websocket timeout");
  process.exit(1);
}, 5000).unref();

socket.addEventListener("open", () => socket.send("Hello?"));
socket.addEventListener("message", (event) => {
  process.stdout.write(`${event.data}\n`, () => process.exit(0));
});
socket.addEventListener("error", () => {
  console.error("websocket error");
  process.exit(1);
});
