FROM swift:5.7-focal as build
#2
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && rm -rf /var/lib/apt/lists/*
#3
WORKDIR /build
#4
COPY ./Package.* ./
RUN swift package resolve
#5
COPY . .
RUN swift build --enable-test-discovery -c release
#6
WORKDIR /staging
RUN cp "$(swift build --package-path /build -c release \
    --show-bin-path)/Run" ./
RUN [ -d /build/Public ] && \
    { mv /build/Public ./Public && chmod -R a-w ./Public; } \
    || true
RUN [ -d /build/Resources ] && \
    { mv /build/Resources ./Resources && \
    chmod -R a-w ./Resources; } || true
#7
FROM swift:5.7-focal-slim
#8
RUN export DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get -q update && \
    apt-get -q dist-upgrade -y && \
    rm -r /var/lib/apt/lists/*
#9
RUN useradd --user-group --create-home --system \
    --skel /dev/null --home-dir /app vapor
# 10
WORKDIR /app
# 11
COPY --from=build --chown=vapor:vapor /staging /app
# 12
USER vapor:vapor
# 13
EXPOSE 8080
# 14
ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
