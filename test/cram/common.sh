curl_cmd() {
  curl --silent --retry 2 --retry-connrefused "localhost:8080$1" "${@:2}"
}
