#!/bin/bash
set -e

# Путь к директории проекта
PROJECT_DIR=/home/HMAC_SHA-256_server

# Удаляем старый проект и создаём заново
rm -rf "$PROJECT_DIR"
cargo new "$PROJECT_DIR" --bin
cd "$PROJECT_DIR"

# Делаем необходимые зависимости в Cargo.toml
# Находим секцию [dependencies] и добавляем новые строки после неё
sed -i '/\[dependencies\]/a \
actix-web = "4"\
serde = { version = "1", features = ["derive"] }\
serde_json = "1"\
hmac = "0.12"\
sha2 = "0.10"\
base64 = "0.21"' Cargo.toml

# Записываем код сервера без поля nonce
cat > src/main.rs <<'EOF'
use actix_web::{post, App, HttpResponse, HttpServer, Responder, web};
use serde::Deserialize;
use hmac::{Hmac, Mac};
use sha2::Sha256;
use base64;

type HmacSha256 = Hmac<Sha256>;

#[derive(Deserialize)]
struct Session {
    user_id: u32,
    expires: u32,
    role: u8
}

#[post("/session")]
async fn session(data: web::Json<Session>) -> impl Responder {
    let key = b"supersecretkey";
    let mut mac = HmacSha256::new_from_slice(key).unwrap();
    mac.update(&data.user_id.to_be_bytes());
    mac.update(&data.expires.to_be_bytes());
    mac.update(&[data.role]);

    let tag = mac.finalize().into_bytes();
    HttpResponse::Ok().body(base64::encode(tag))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("🚀 HMAC_SHA-256 server запущен на http://0.0.0.0:8081/session");
    HttpServer::new(|| App::new().service(session))
        .bind(("0.0.0.0", 8081))?
        .run()
        .await
}
EOF

# Сборка и запуск
cargo build --release
./target/release/HMAC_SHA-256_server > /tmp/HMAC_SHA-256_server.log 2>&1 &
echo $! > /tmp/HMAC_SHA-256_server.pid