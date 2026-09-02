#!/usr/bin/env bash
# eid.gerege.mn-ийг барьж, шинэчлэх. Серверийн /opt/eid-nexus/src дотроос
# ажиллана.
#
#   cd /opt/eid-nexus/src && git pull && ./deploy.sh
#
# Юу хийдэг вэ: энэ бүтээгдэхүүний backend-ийг барина (бүрхүүл нь цөмийн
# нийтэлсэн образ, WEB_IMAGE), стекийг СОЛИОД эрүүл эсэхийг асууна.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$SRC_DIR")"
COMPOSE="$SRC_DIR/deploy/docker-compose.yml"
# Статик домэйнууд. Агуулга нь репод тул `git pull` бүрд шинэчлэгдэх ёстой.
SITES="$SRC_DIR/deploy/docker-compose.sites.yml"

[ -f "$APP_DIR/.env" ] || { echo "$APP_DIR/.env алга. .env.example-ээс хуулж, нууцуудыг нь бөглө." >&2; exit 1; }

docker build -q -t eid-nexus:latest -f "$SRC_DIR/deploy/Dockerfile" "$SRC_DIR"

cp "$APP_DIR/.env" "$SRC_DIR/deploy/.env"
# Татаж чадахгүй нь өөрөө үхлийн шалтгаан биш — образ хостод аль хэдийн байж
# болно. Байхгүй бол дараагийн `up` нь тодорхой алдаа өгнө.
docker compose -f "$COMPOSE" pull -q web || echo "анхааруулга: бүрхүүлийн образыг татаж чадсангүй; хостод байгааг нь хэрэглэнэ" >&2
# --force-recreate нь сайн дурын биш: `up -d` шинэ образ барьсан ч ажиллаж
# байгаа контейнерийг хэвээр үлдээж чадах бөгөөд тэгвэл эрүүл мэндийн шалгалт
# ХУУЧИН хувилбар дээр ногоон өнгө өгнө.
docker compose -f "$COMPOSE" up -d --force-recreate --remove-orphans

# Статик домэйнууд (dwh, backups). Тусдаа төсөл тул платформын rollout-ыг
# хойшлуулахгүй — унасан ч энэ скрипт үргэлжилнэ: хоёр тайлбар хуудас нь
# байрлуулалт амжилттай болсон эсэхийг шийддэг зүйл биш.
docker compose -f "$SITES" up -d --remove-orphans >/dev/null \
  || echo "анхааруулга: статик домэйнуудыг шинэчилж чадсангүй" >&2

# Ажиглалт, алдааны хөтлөлт нь ЗОРИУДААР энд байхгүй. Тэдгээр нь өөрсдийн
# compose төсөлтэй бөгөөд платформын rollout тэднийг дахин асаах ёсгүй:
# байрлуулалт бүрд арван таван ажиглалтын контейнер дахин үүсэх нь яг тэдний
# ажиглах ёстой мөчид тэднийг сохлоно.
#
#   docker compose -f deploy/docker-compose.monitoring.yml --env-file ../.env up -d
#   docker compose -f deploy/docker-compose.glitchtip.yml  --env-file ../.env up -d

# Барьсан образ л ажиллаж байгаа эсэх. Дээрх мөрийн амлалтыг шалгаж байна.
running="$(docker inspect -f '{{.Image}}' gerege_eid_nexus_backend)"
built="$(docker images -q --no-trunc eid-nexus:latest)"
[ "$running" = "$built" ] || { echo "backend хуучин образ дээр ажиллаж байна: $running != $built" >&2; exit 1; }

# Шалгалт: гурван хариу — API эрүүл, бүрхүүл ирж байна, брэнд .env-ийнхээ
# нэрийг хэлж байна. Гурав дахь нь энэ байрлуулалтыг цөмийн анхдагчаас ялгадаг
# цорын ганц зүйл тул сайн дурын биш.
for i in $(seq 1 30); do
  curl -fsS http://127.0.0.1:8082/health >/dev/null 2>&1 && break
  [ "$i" -eq 30 ] && { echo "backend 60 секундэд эрүүл болсонгүй" >&2; docker compose -f "$COMPOSE" logs --tail 40 backend >&2; exit 1; }
  sleep 2
done

brand="$(grep -E '^BRAND_NAME=' "$APP_DIR/.env" | cut -d= -f2-)"
for i in $(seq 1 30); do
  if body="$(curl -fsS http://127.0.0.1:3008/login 2>/dev/null)"; then
    [ -z "$brand" ] && break
    case "$body" in *"$brand"*) break ;; esac
  fi
  [ "$i" -eq 30 ] && { echo "бүрхүүл 60 секундэд «${brand:-хариу}» өгсөнгүй" >&2; exit 1; }
  sleep 2
done

# Хувилбарын тамга буусан эсэх. 1.1.0 гэж хариулбал -X флаг оносонгүй гэсэн үг
# бөгөөд тэр образ манифестуудаа татгалзана.
echo "OK: $(grep -E '^PUBLIC_ORIGIN=' "$APP_DIR/.env" | cut -d= -f2) — $brand"
curl -fsS http://127.0.0.1:8082/health
