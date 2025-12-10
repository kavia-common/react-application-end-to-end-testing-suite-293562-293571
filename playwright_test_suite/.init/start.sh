#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/react-application-end-to-end-testing-suite-293562-293571/playwright_test_suite"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/.validation" "$WORKSPACE/tests"
# ensure index.html with <title>
if [ ! -f "$WORKSPACE/index.html" ]; then
  cat > "$WORKSPACE/index.html" <<'HTML'
<!doctype html>
<html>
<head><title>Playwright local server</title></head>
<body><h1>Playwright local server</h1></body>
</html>
HTML
fi
# Choose port: prefer 8080, fall back to ephemeral
PORT=8080
if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${PORT}$"; then
  PORT=$(node -e "const srv=require('net').createServer(); srv.listen(0,()=>{console.log(srv.address().port); srv.close();});" 2>/dev/null || echo 0)
  if [ -z "$PORT" ] || [ "$PORT" = "0" ]; then
    echo "ERROR: failed to find free port" >&2
    exit 30
  fi
fi
NODE_SERVER_LOG="$WORKSPACE/.validation/static_server.log"
# Start node static server in background; capture PID
node -e "const http=require('http'),fs=require('fs');const srv=http.createServer((r,s)=>{if(r.url=='/'){s.writeHead(200,{'Content-Type':'text/html'});s.end(fs.readFileSync('index.html'))}else{s.writeHead(404);s.end('not found')}});srv.listen(${PORT},'0.0.0.0',()=>console.log('listening'));process.on('SIGTERM',()=>srv.close(()=>process.exit(0)));process.on('SIGINT',()=>srv.close(()=>process.exit(0)));" > "$NODE_SERVER_LOG" 2>&1 &
SERVER_PID=$!
# export PID and PORT for other scripts
echo "$SERVER_PID" > "$WORKSPACE/.validation/server.pid"
echo "$PORT" > "$WORKSPACE/.validation/server.port"
# wait and verify
for i in 1 2 3 4 5; do
  sleep 0.5
  if curl --silent --fail "http://localhost:${PORT}/" >/dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 5 ]; then
    echo "ERROR: static server failed to respond; see $NODE_SERVER_LOG" >&2
    sed -n '1,200p' "$NODE_SERVER_LOG" >&2 || true
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
    exit 31
  fi
done
# write minimal server info
echo "started" > "$WORKSPACE/.validation/server.status"
echo "$PORT" > "$WORKSPACE/.validation/server.port"
