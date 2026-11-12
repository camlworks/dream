# Use the PID to determine the port to ensure uniqueness
export DREAM_PORT=$((10000 + $$ % 20000))

curl_cmd() {
  # Retry until the server accepts connections.
  # Avoid curl's --retry as it also retries HTTP 5xx responses
  # Instead, only retry on exit code 7 (failed to connect)
  local attempt=0
  until curl --silent "localhost:$DREAM_PORT$1" "${@:2}" 2>&1; do
    [ "$?" -eq 7 ] || break
    attempt=$((attempt + 1))
    [ "$attempt" -lt 50 ] || break
    sleep 0.1
  done \
    | sed 's/User-Agent: .*/User-Agent: <omitted>/' \
    | sed -E 's/(::1|127\.0\.0\.1):[0-9]*/<client>:<omitted>/' \
    | sed 's/dream.request_id: [0-9]*/dream.request_id: <omitted>/' \
    | sed -E 's/dream\.fd: [0-9]+/dream.fd: <omitted>/' \
    | sed 's/localhost:[0-9]*/localhost:<omitted>/' \
    | sed -E 's/(in file [^,]*), line [0-9]*, characters [0-9]*-[0-9]*/\1, line <omitted>, characters <omitted>/'
}


# Start a server and capture its output in server.log. Tests can assert on the
# captured output with server_log below.
start_server() {
  "$@" > server.log 2>&1 &
}

# Print the captured server output with values that vary between runs and
# machines normalized. In particular, the timestamps are removed.
server_log() {
  sed -E \
    -e 's/^[0-9]{2}\.[0-9]{2}\.[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3} //' \
    -e 's/localhost:[0-9]+/localhost:<omitted>/g' \
    -e 's/(::1|127\.0\.0\.1):[0-9]+/<client>:<omitted>/g' \
    -e 's/( fd )[0-9]+( .*)?$/\1<omitted>/' \
    -e 's/ in [0-9]+ μs/ in <omitted>/g' \
    -e 's/dream\.request_id: [0-9]+/dream.request_id: <omitted>/g' \
    -e 's/dream\.fd: [0-9]+/dream.fd: <omitted>/g' \
    -e 's/(in file [^,]*), lines? [0-9-]*, characters [0-9-]*/\1, line <omitted>, characters <omitted>/g' \
    -e 's/SSL connection\(\) error: .*/SSL connection() error: <omitted>/' \
    server.log
}

# Wait until the server has written at least COUNT lines matching PATTERN to
# server.log. This is only needed when the last log lines are written after the
# client command returns, as for streaming and WebSocket responses.
wait_for_log() {
  local pattern="$1" count="${2:-1}" attempt=0
  until [ "$(grep -cE "$pattern" server.log)" -ge "$count" ]; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 100 ]; then
      echo "Timed out waiting for server log: $pattern" >&2
      return 1
    fi
    sleep 0.1
  done
}

# Wait for the example server(s) to exit before the cram shell returns. Dune
# terminates the process group once the shell exits (3.20+, ocaml/dune#11841),
# but does not wait for those processes. Under `make test`'s bisect
# instrumentation, a server handling SIGTERM writes its *.coverage file into
# the sandbox while dune is deleting it, which makes dune fail with "Directory
# not empty". `exit 0` preserves dune's own EXIT trap behavior.
trap 'kill $(jobs -p) 2>/dev/null; wait 2>/dev/null; exit 0' EXIT
