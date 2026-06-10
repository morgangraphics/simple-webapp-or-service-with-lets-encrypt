FROM ubuntu:22.04

# Install iptables, conntrack, python3 (http.server), curl
RUN apt-get update && apt-get install -y \
    iptables \
    conntrack \
    python3 \
    curl \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /test
COPY test_string_match.sh test_with_redirect.sh ./
RUN chmod +x test_string_match.sh test_with_redirect.sh

# run_tests.sh runs both test scripts sequentially and exits non-zero if any fail
COPY run_tests.sh ./
RUN chmod +x run_tests.sh

CMD ["/test/run_tests.sh"]
