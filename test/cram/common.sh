set -o pipefail
set -o nounset

export DREAM_PORT=$((10000 + RANDOM % 55000))

curl_cmd() {
  curl --silent --retry 2 --retry-connrefused "localhost:$DREAM_PORT$1" "${@:2}" 2>&1 \
    | sed 's/User-Agent: .*/User-Agent: <omitted>/' \
    | sed 's/::1:[0-9]*/::1:<omitted>/' \
    | sed 's/dream.request_id: [0-9]*/dream.request_id: <omitted>/' \
    | sed 's/localhost:[0-9]*/localhost:<omitted>/'
}
