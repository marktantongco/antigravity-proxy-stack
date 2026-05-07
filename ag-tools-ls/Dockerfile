FROM rust:1.75-bookworm as builder

WORKDIR /app
# Clone the actual repo if accessible, otherwise use placeholder
RUN git clone https://github.com/topics/antigravity-tools-ls /app/src 2>/dev/null ||     (echo "Using placeholder for ag-tools-ls" &&      mkdir -p /app/src &&      cat > /app/Cargo.toml << 'CARGO'
[package]
name = "ag-tools-ls"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio = { version = "1", features = ["full"] }
hyper = { version = "1", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
reqwest = { version = "0.11", features = ["socks"] }
CARGO
     cat > /app/src/main.rs << 'RUST'
use std::env;
use std::net::SocketAddr;
use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server, StatusCode};

async fn handle(req: Request<Body>) -> Result<Response<Body>, hyper::Error> {
    let path = req.uri().path();
    if path == "/health" {
        return Ok(Response::builder()
            .status(StatusCode::OK)
            .body(Body::from("healthy"))
            .unwrap());
    }
    Ok(Response::builder()
        .status(StatusCode::OK)
        .body(Body::from(format!("AG Tools LS: {}", path)))
        .unwrap())
}

#[tokio::main]
async fn main() {
    let port = env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    let addr: SocketAddr = format!("0.0.0.0:{}", port).parse().unwrap();

    let make_svc = make_service_fn(|_conn| async {
        Ok::<_, hyper::Error>(service_fn(handle))
    });

    let server = Server::bind(&addr).serve(make_svc);
    println!("AG Tools LS listening on {}", addr);
    if let Err(e) = server.await {
        eprintln!("Server error: {}", e);
    }
}
RUST
    )

WORKDIR /app
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/ag-tools-ls /usr/local/bin/ag-tools-ls
EXPOSE 3001
ENV PORT=3001
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3     CMD wget -q --spider http://localhost:3001/health || exit 1
CMD ["ag-tools-ls"]
