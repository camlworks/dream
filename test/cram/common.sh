curl_cmd() {
  # Filter out User-Agent header to avoid test flakiness from curl's default UA
    curl --silent --retry 2 --retry-connrefused "localhost:8080$1" "${@:2}" 2>&1 \
        | grep -v "User-Agent:"
}
