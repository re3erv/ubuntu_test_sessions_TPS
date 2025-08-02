#!/bin/bash
set -e

# Установим и запустим Redis-демон, если нужно
if ! command -v redis-server &>/dev/null; then
  apt update
  apt install -y redis-server
fi
if ! pgrep -x redis-server &>/dev/null; then
  echo "🚀 Запускаем локальный redis-server"
  redis-server --daemonize yes
  sleep 1
fi

echo "🔧 Строим Rust-сервис с поддержкой постоянного соединения к Redis"
PROJECT_DIR=/home/redis_server
rm -rf "$PROJECT_DIR"
cargo new "$PROJECT_DIR" --bin
cd "$PROJECT_DIR"

# Добавляем зависимости
sed -i '/\[dependencies\]/a \
actix-web = "4"\
serde = { version = "1", features = ["derive"] }\
serde_json = "1"\
redis = { version = "0.24", features = ["tokio-comp"] }\
tokio = { version = "1", features = ["macros","rt-multi-thread"] }' Cargo.toml

# Пишем код сервера с MultiplexedConnection
cat > src/main.rs <<'EOF'
use actix_web::{post, web, App, HttpResponse, HttpServer, Responder};
use redis::aio::MultiplexedConnection;
use redis::AsyncCommands;
use serde::Deserialize;

#[derive(Deserialize)]
struct Session {
    user_id: u32,
    expires: u32,
    role: u8,
}

#[post("/session")]
async fn session(data: web::Json<Session>, conn: web::Data<MultiplexedConnection>) -> impl Responder {
    let key = format!("session:{}:{}:{}", data.user_id, data.expires, data.role);
    let mut c = conn.get_ref().clone();
    let result: redis::RedisResult<()> = c.set_ex(&key, "1", 3600).await;
    if result.is_err() {
        return HttpResponse::InternalServerError().body("Redis SET failed");
    }
    HttpResponse::Ok().finish()
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Открываем клиент и создаём мультиплексированное соединение один раз
    let client = redis::Client::open("redis://0.0.0.0/").unwrap();
    let conn = client.get_multiplexed_tokio_connection().await.unwrap();
    println!("🚀 Redis server запущен на http://0.0.0.0:8082/session");

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(conn.clone()))
            .service(session)
    })
    .bind(("0.0.0.0", 8082))?
    .run()
    .await
}
EOF

# Сборка и запуск сервера
cargo build --release
./target/release/redis_server > /tmp/redis_server.log 2>&1 &
echo $! > /tmp/redis_server.pid