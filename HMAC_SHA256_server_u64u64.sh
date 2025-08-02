#!/bin/bash
echo "🚀 Устанавливаем HMAC-SHA256 сервер (Session {user_id: u64, expires: u64, role: u8})"

PROJECT_DIR="/home/HMAC_SHA256_server_u64u64"
APP_NAME="HMAC_SHA256_server_u64u64"
PORT=8092

rm -rf "$PROJECT_DIR"
cargo new "$PROJECT_DIR" --bin
cd "$PROJECT_DIR"

# Добавляем зависимости
sed -i '/\[dependencies\]/a \
actix-web = "4"\
serde = { version = "1", features = ["derive"] }\
serde_json = "1"\
hmac = "0.12"\
sha2 = "0.10"\
base64 = "0.21"' Cargo.toml

cat > src/main.rs <<'EOF'
use actix_web::{post, web, App, HttpServer, HttpResponse, Responder};
use serde::{Serialize, Deserialize};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use base64::{engine::general_purpose, Engine};
use std::time::{SystemTime, UNIX_EPOCH};

type HmacSha256 = Hmac<Sha256>;

#[derive(Serialize, Deserialize)]
struct Session {
    user_id: u64,
    expires: u64,
    role: u8,
}

fn current_unix_time() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
}

const SECRET_KEY: &[u8] = b"verysecretkey_that_should_be_long_and_random!";

#[post("/session")]
async fn create_session(session: web::Json<Session>) -> impl Responder {
    if session.expires < current_unix_time() {
        return HttpResponse::BadRequest().body("expires time is in the past");
    }

    let serialized = match serde_json::to_vec(&session.0) {
        Ok(data) => data,
        Err(_) => return HttpResponse::InternalServerError().finish(),
    };

    let mut mac = HmacSha256::new_from_slice(SECRET_KEY).expect("HMAC can take key of any size");
    mac.update(&serialized);
    let result = mac.finalize();
    let code_bytes = result.into_bytes();

    // Конкатенация: json + hmac
    let mut token_bytes = serialized.clone();
    token_bytes.extend_from_slice(&code_bytes);

    let token_base64 = general_purpose::STANDARD.encode(token_bytes);

    HttpResponse::Ok().body(token_base64)
}

#[post("/session/check")]
async fn check_session(token: String) -> impl Responder {
    let data = match general_purpose::STANDARD.decode(&token) {
        Ok(d) => d,
        Err(_) => return HttpResponse::BadRequest().json(serde_json::json!({"valid": false, "reason": "Base64 decode error"})),
    };

    if data.len() < 32 {
        return HttpResponse::BadRequest().json(serde_json::json!({"valid": false, "reason": "Data too short"}));
    }

    let (json_bytes, hmac_bytes) = data.split_at(data.len() - 32);

    let mut mac = HmacSha256::new_from_slice(SECRET_KEY).expect("HMAC can take key of any size");
    mac.update(json_bytes);

    if mac.verify_slice(hmac_bytes).is_err() {
        return HttpResponse::Ok().json(serde_json::json!({"valid": false, "reason": "HMAC verification failed"}));
    }

    let session: Session = match serde_json::from_slice(json_bytes) {
        Ok(s) => s,
        Err(_) => return HttpResponse::Ok().json(serde_json::json!({"valid": false, "reason": "Deserialization failed"})),
    };

    let now = current_unix_time();
    if session.expires < now {
        return HttpResponse::Ok().json(serde_json::json!({"valid": false, "reason": "Session expired"}));
    }

    HttpResponse::Ok().json(serde_json::json!({"valid": true, "reason": serde_json::Value::Null}))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("🚀 HMAC-SHA256 сервер запущен на порту 8092");
    HttpServer::new(|| {
        App::new()
            .service(create_session)
            .service(check_session)
    })
    .bind(("0.0.0.0", 8092))?
    .run()
    .await
}
EOF

cargo build --release || { echo "❌ Ошибка сборки"; exit 1; }
./target/release/$APP_NAME &
echo $! > /tmp/${APP_NAME}.pid

echo "✅ Сервер запущен: http://0.0.0.0:$PORT/session и /session/check"
