#!/bin/bash
set -e

echo "🚀 Устанавливаем сервер HMAC-BLAKE3..."

# Удаляем старую директорию, если есть
rm -rf /home/HMAC-BLAKE3_server
mkdir -p /home/HMAC-BLAKE3_server/src
cd /home/HMAC-BLAKE3_server

# Создаём Cargo.toml
cat > Cargo.toml <<EOF
[package]
name = "HMAC-BLAKE3_server"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
blake3 = "1.5.0"
EOF

# Создаём src/main.rs
cat > src/main.rs <<'EOF'
use actix_web::{post, web, App, HttpResponse, HttpServer, Responder};
use serde::{Deserialize, Serialize};
use blake3;

#[derive(Deserialize, Serialize)]
struct Session {
    user_id: u32,
    expires: u32,
    role: u8,
}

#[post("/session")]
async fn session_handler(session: web::Json<Session>) -> impl Responder {
    let key: [u8; 32] = *b"0123456789abcdef0123456789abcdef";

    let session_json = match serde_json::to_vec(&*session) {
        Ok(json) => json,
        Err(_) => return HttpResponse::BadRequest().body("Serialization error"),
    };

    let _tag = blake3::keyed_hash(&key, &session_json);

    HttpResponse::Ok().finish()
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| App::new().service(session_handler))
        .bind("0.0.0.0:8084")?
        .run()
        .await
}
EOF

echo "🔧 Сборка проекта..."
cargo build --release

echo "✅ Сервер HMAC-BLAKE3 установлен и запущен на http://0.0.0.0:8084/session"
./target/release/HMAC-BLAKE3_server &
