#!/bin/bash

echo "🚀 Устанавливаем AES-GCM-SIV сервер"

# Создание проекта
PROJECT_DIR="/home/AES-GCM-SIV_server"
APP_NAME="AES-GCM-SIV_server"
PORT=8083

rm -rf "$PROJECT_DIR"
cargo new "$PROJECT_DIR" --bin
cd "$PROJECT_DIR"

# Добавляем зависимости в Cargo.toml
sed -i '/\[dependencies\]/a \
actix-web = "4"\
serde = { version = "1", features = ["derive"] }\
serde_json = "1"\
aes-gcm-siv = "0.11"\
rand = "0.8"\
base64 = "0.21"' Cargo.toml

# Заполнение src/main.rs
cat > src/main.rs <<'EOF'
use actix_web::{post, App, HttpServer, Responder, HttpResponse, web};
use serde::{Deserialize, Serialize};
use aes_gcm_siv::{Aes256GcmSiv, aead::{Aead, KeyInit, generic_array::GenericArray}};
use rand::{RngCore, rngs::OsRng};
use base64::{engine::general_purpose, Engine};

#[derive(Serialize, Deserialize)]
struct Session {
    user_id: u32,
    expires: u32,
    role: u8,
    nonce: u16,
}

#[post("/session")]
async fn create_session(session: web::Json<Session>) -> impl Responder {
    let key = GenericArray::from_slice(b"anexampleverysecurekey12345678!!"); // 32 bytes
    let cipher = Aes256GcmSiv::new(key);

    let serialized = match serde_json::to_vec(&session.0) {
        Ok(data) => data,
        Err(_) => return HttpResponse::InternalServerError().finish(),
    };

    let mut nonce_bytes = [0u8; 12];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = aes_gcm_siv::Nonce::from_slice(&nonce_bytes);

    let ciphertext = match cipher.encrypt(nonce, serialized.as_ref()) {
        Ok(ct) => ct,
        Err(_) => return HttpResponse::InternalServerError().finish(),
    };

    let mut result = nonce_bytes.to_vec();
    result.extend_from_slice(&ciphertext);

    HttpResponse::Ok().body(general_purpose::STANDARD.encode(result))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("🚀 AES-GCM-SIV сервер запущен на порту 8083");
    HttpServer::new(|| App::new().service(create_session))
        .bind(("0.0.0.0", 8083))?
        .run()
        .await
}
EOF

# Сборка и запуск
cargo build --release
./target/release/$APP_NAME &
echo $! > /tmp/AES-GCM-SIV_server.pid

echo "✅ Сервер запущен: http://0.0.0.0:$PORT/session"
