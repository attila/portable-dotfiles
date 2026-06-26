// Patches https.Agent.prototype.createConnection to tunnel through an HTTP
// CONNECT proxy named by HTTPS_PROXY. Activated only inside sandboxes that
// set HTTPS_PROXY (nono); a no-op everywhere else.
//
// Why: AWS SDK v3's NodeHttpHandler builds its own https.Agent and passes
// it explicitly to https.request, which short-circuits Node's
// NODE_USE_ENV_PROXY resolution. Patching createConnection on the Agent
// prototype catches every SDK-built agent at call time.

import https from 'node:https';
import net from 'node:net';
import tls from 'node:tls';

const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy;

if (proxyUrl) {
  const u = new URL(proxyUrl);
  const proxyHost = u.hostname;
  const proxyPort = Number(u.port) || 80;
  const auth = u.username
    ? Buffer.from(
        `${decodeURIComponent(u.username)}:${decodeURIComponent(u.password)}`,
      ).toString('base64')
    : null;

  https.Agent.prototype.createConnection = function patchedCreateConnection(
    options,
    callback,
  ) {
    const targetHost = options.host;
    const targetPort = options.port || 443;
    const servername = options.servername || targetHost;

    const tcp = net.connect(proxyPort, proxyHost);

    let buf = '';
    const onData = (chunk) => {
      buf += chunk.toString('latin1');
      const eoh = buf.indexOf('\r\n\r\n');
      if (eoh < 0) return;
      tcp.removeListener('data', onData);
      const statusLine = buf.slice(0, buf.indexOf('\r\n'));
      const match = statusLine.match(/^HTTP\/1\.[01] (\d+)/);
      if (!match || match[1] !== '200') {
        const err = new Error(`Proxy CONNECT failed: ${statusLine}`);
        if (callback) return callback(err);
        tcp.destroy(err);
        return;
      }
      const tlsSock = tls.connect({
        socket: tcp,
        servername,
        ALPNProtocols: options.ALPNProtocols,
      });
      if (callback) callback(null, tlsSock);
    };

    tcp.on('data', onData);
    tcp.once('error', (err) => {
      if (callback) callback(err);
    });
    tcp.once('connect', () => {
      let req = `CONNECT ${targetHost}:${targetPort} HTTP/1.1\r\n`;
      req += `Host: ${targetHost}:${targetPort}\r\n`;
      if (auth) req += `Proxy-Authorization: Basic ${auth}\r\n`;
      req += '\r\n';
      tcp.write(req);
    });
  };
}
