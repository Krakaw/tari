#FROM rust:1.42.0 as builder
FROM quay.io/tarilabs/rust_tari-build-with-deps:nightly-2020-01-08 as builder

WORKDIR /tari_base_node

# Copy the dependency lists
COPY ./Cargo.toml ./Cargo.toml
COPY ./applications/tari_base_node/Cargo.toml ./applications/tari_base_node/Cargo.toml
COPY ./applications/test_faucet/Cargo.toml ./applications/test_faucet/Cargo.toml
COPY ./base_layer/core/Cargo.toml ./base_layer/core/Cargo.toml
COPY ./base_layer/key_manager/Cargo.toml ./base_layer/key_manager/Cargo.toml
COPY ./base_layer/mmr/Cargo.toml ./base_layer/mmr/Cargo.toml
COPY ./base_layer/mmr/benches ./base_layer/mmr/benches
COPY ./base_layer/p2p/Cargo.toml ./base_layer/p2p/Cargo.toml
COPY ./base_layer/service_framework/Cargo.toml ./base_layer/service_framework/Cargo.toml
COPY ./base_layer/wallet/Cargo.toml ./base_layer/wallet/Cargo.toml
COPY ./base_layer/wallet_ffi/Cargo.toml ./base_layer/wallet_ffi/Cargo.toml
COPY ./common/Cargo.toml ./common/Cargo.toml
COPY ./comms/Cargo.toml ./comms/Cargo.toml
COPY ./comms/dht/Cargo.toml ./comms/dht/Cargo.toml
COPY ./infrastructure/derive/Cargo.toml ./infrastructure/derive/Cargo.toml
COPY ./infrastructure/shutdown/Cargo.toml ./infrastructure/shutdown/Cargo.toml
COPY ./infrastructure/storage/Cargo.toml ./infrastructure/storage/Cargo.toml
COPY ./infrastructure/test_utils/Cargo.toml ./infrastructure/test_utils/Cargo.toml

# Protobuf
COPY ./base_layer/core/src/base_node/proto ./base_layer/core/src/base_node/proto
COPY ./base_layer/core/src/mempool/proto ./base_layer/core/src/mempool/proto
COPY ./base_layer/core/src/proto ./base_layer/core/src/proto
COPY ./base_layer/core/src/transactions/proto ./base_layer/core/src/transactions/proto
COPY ./base_layer/core/src/transactions/transaction_protocol/proto ./base_layer/core/src/transactions/transaction_protocol/proto
COPY ./base_layer/p2p/src/proto ./base_layer/p2p/src/proto
COPY ./comms/dht/src/proto ./comms/dht/src/proto
COPY ./comms/src/proto ./comms/src/proto

RUN rustup component add rustfmt --toolchain nightly-2020-01-08-x86_64-unknown-linux-gnu \
    && find /tari_base_node -name Cargo.toml -exec sh -c 'mkdir -p "$(dirname {})/src" && echo "// Temp file for dependency caching" > "$(dirname {})/src/lib.rs"' \; \
    && cargo build -p tari_base_node --release \
    && rm -rf ./*

COPY . .

RUN cargo build -p tari_base_node --release

# Create a base minimal image for adding our executables to
FROM bitnami/minideb:stretch as base
RUN apt update && apt install \
    openssl \
    libsqlite3-0 \
    curl \
    bash \
    iputils-ping \
    less \
    telnet \
    -y

# Now create a new image with only the essentials and throw everything else away
FROM base
COPY --from=builder /tari_base_node/target/release/tari_base_node /usr/bin/
#COPY --from=builder /basenode/target/release/tari_base_node.d /etc/tari_base_node.d
RUN mkdir /etc/tari_base_node.d
COPY --from=builder /tari_base_node/config/tari_config_sample.toml /etc/tari_base_node.d/tari_config_sample.toml
COPY --from=builder /tari_base_node/common/logging/log4rs-sample.yml /root/.tari/log4rs.yml

CMD ["tari_base_node"]
