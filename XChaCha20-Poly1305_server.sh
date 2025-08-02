#!/bin/bash
set -e

echo "🚀 Устанавливаем сервер XChaCha20-Poly1305..."

rm -rf /home/XChaCha20-Poly1305_server
mkdir -p /home/XChaCha20-Poly1305_server/src
cd /home/XChaCha20-Poly1305_server

cat > Cargo.toml <<EOF
[package]
name = "XChaCha20-Poly1305_server"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
chacha20poly1305 = "0.10"
rand_core = "0.6"
EOF

cat > src/main.rs <<'EOF'
use actix_web::{post, web, App, HttpResponse, HttpServer, Responder};
use chacha20poly1305::{XChaCha20Poly1305, Key, XNonce, aead::{Aead, KeyInit}};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
struct Session {
    user_id: u32,
    expires: u32,
    role: u8,
}

#[post("/session")]
async fn session_handler(session: web::Json<Session>) -> impl Responder {
    // Ключ 32 байта
    let key = Key::from_slice(b"0123456789abcdef0123456789abcdef");
    let cipher = XChaCha20Poly1305::new(key);

    // Nonce ровно 24 байта
    let nonce = XNonce::from_slice(b"0123456789abcdef01234567");

    let session_json = match serde_json::to_vec(&*session) {
        Ok(json) => json,
        Err(_) => return HttpResponse::BadRequest().body("Serialization error"),
    };

    match cipher.encrypt(nonce, session_json.as_ref()) {
        Ok(_) => HttpResponse::Ok().finish(),
        Err(_) => HttpResponse::InternalServerError().body("Encryption failed"),
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| App::new().service(session_handler))
        .bind("0.0.0.0:8085")?
        .run()
        .await
}
EOF

echo "🔧 Сборка проекта..."
cargo build --release

echo "✅ Сервер XChaCha20-Poly1305 установлен и запущен на http://0.0.0.0:8085/session"
./target/release/XChaCha20-Poly1305_server &
