#!/bin/bash
echo "🚀 Устанавливаем AES-GCM-SIV сервер (Session {user_id: u64, expires: u64, role: u8})"

PROJECT_DIR="/home/AES-GCM-SIV_server_u64u64"
APP_NAME="AES-GCM-SIV_server_u64u64"
PORT=8091

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

# Записываем main.rs
cat > src/main.rs <<'EOF'
use actix_web::{post, web, App, HttpServer, HttpResponse, Responder};
use serde::{Serialize, Deserialize};
use aes_gcm_siv::{
    Aes256GcmSiv,
    aead::{Aead, KeyInit, OsRng, generic_array::GenericArray, Nonce},
};
use base64::{engine::general_purpose, Engine};
use rand::RngCore;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize, Deserialize)]
struct Session {
    user_id: u64,
    expires: u64,
    role: u8,
}

fn current_unix_time() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
}

#[post("/session")]
async fn create_session(session: web::Json<Session>) -> impl Responder {
    let key_bytes = b"anexampleverysecurekey12345678!!"; // 32 bytes
    let key = GenericArray::from_slice(key_bytes);
    let cipher = Aes256GcmSiv::new(key);

    if session.expires < current_unix_time() {
        return HttpResponse::BadRequest().body("expires time is in the past");
    }

    let serialized = match serde_json::to_vec(&session.0) {
        Ok(data) => data,
        Err(_) => return HttpResponse::InternalServerError().finish(),
    };

    let mut nonce_bytes = [0u8; 12];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::<Aes256GcmSiv>::from_slice(&nonce_bytes);

    let ciphertext = match cipher.encrypt(nonce, serialized.as_ref()) {
        Ok(ct) => ct,
        Err(_) => return HttpResponse::InternalServerError().finish(),
    };

    let mut result = nonce_bytes.to_vec();
    result.extend_from_slice(&ciphertext);

    let encoded = general_purpose::STANDARD.encode(result);

    HttpResponse::Ok().body(encoded)
}

#[post("/session/check")]
async fn check_session(token: String) -> impl Responder {
    let key_bytes = b"anexampleverysecurekey12345678!!"; // 32 bytes
    let key = GenericArray::from_slice(key_bytes);
    let cipher = Aes256GcmSiv::new(key);

    let data = match general_purpose::STANDARD.decode(&token) {
        Ok(d) => d,
        Err(_) => return HttpResponse::BadRequest().json(serde_json::json!({"valid": false, "reason": "Base64 decode error"})),
    };

    if data.len() < 12 {
        return HttpResponse::BadRequest().json(serde_json::json!({"valid": false, "reason": "Data too short"}));
    }

    let (nonce_bytes, ciphertext) = data.split_at(12);
    let nonce = Nonce::<Aes256GcmSiv>::from_slice(nonce_bytes);

    let decrypted = match cipher.decrypt(nonce, ciphertext) {
        Ok(pt) => pt,
        Err(_) => return HttpResponse::BadRequest().json(serde_json::json!({"valid": false, "reason": "Decryption failed"})),
    };

    let session: Session = match serde_json::from_slice(&decrypted) {
        Ok(s) => s,
        Err(_) => return HttpResponse::BadRequest().json(serde_json::json!({"valid": false, "reason": "Deserialization failed"})),
    };

    let now = current_unix_time();

    if session.expires < now {
        return HttpResponse::Ok().json(serde_json::json!({"valid": false, "reason": "Session expired"}));
    }

    HttpResponse::Ok().json(serde_json::json!({"valid": true, "reason": serde_json::Value::Null}))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("🚀 AES-GCM-SIV сервер запущен на порту 8091");
    HttpServer::new(|| {
        App::new()
            .service(create_session)
            .service(check_session)
    })
    .bind(("0.0.0.0", 8091))?
    .run()
    .await
}
EOF

cargo build --release || { echo "❌ Ошибка сборки"; exit 1; }
./target/release/$APP_NAME &
echo $! > /tmp/${APP_NAME}.pid

echo "✅ Сервер запущен: http://0.0.0.0:$PORT/session и /session/check"
