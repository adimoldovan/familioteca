const net = require('net');
const server = net.createServer();
server.listen(0, () => {
  process.stdout.write(String(server.address().port));
  server.close();
});
