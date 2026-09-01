# eID Gerege

**eid.gerege.mn** — Gerege Nexus платформын нэг байрлуулалт (distribution).
Иргэн өөрийн **eID Mongolia** цахим үнэмлэхээр нэвтэрдэг, өөрийн бааз, өөрийн
нэвтрэлттэй бие даасан суулгац.

Энэ репод **цөмийн код байхгүй**. `go.mod`-ийн нэг мөр л бүхэл түүх нь:

```
github.com/gerege-systems/open-gerege-nexus/backend
```

Энд байх зүйл нь энэ бүтээгдэхүүний өөрийн апп-ууд (`modules/`) бөгөөд репо нь
эхний commit-оосоо **Level 2** байгаа нь санаатай — эхний модуль нэмэх нь
`main.go`-д нэг мөр болохоос биш, байрлуулалтыг нүүлгэх ажил байх ёсгүй
(цөмийн `docs/ECOSYSTEM_GIT_STRATEGY.md`, §1).

Одоогоор өөрийн модульгүй. Бизнес апп-гүй асдаг платформ бол экосистемийн
суурь шалгалт, түр төлөв биш: нэвтрэлт, байгууллага, дэлгүүр, рэйлүүд бүгд
платформынх бөгөөд бүгд энд байна.

## Бүтэц

| Файл | Юу вэ |
|---|---|
| `main.go` | `host.Run` — модулиуд зөвхөн энд орно |
| `deploy/Dockerfile` | backend, migrate, operator/tenant-bootstrap + цөмийн каталог |
| `deploy/docker-compose.yml` | postgres, migrate, backend, бүрхүүл (цөмийн нийтэлсэн образ) |
| `deploy.sh` | сервер дээрх rollout — барих, солих, шалгах |
| `nginx/` | vhost-ууд: `eid.gerege.mn`, `admin.eid.gerege.mn` |
| `.env.example` | `/opt/eid-nexus/.env`-ийн хэлбэр |

Frontend-ийг **барихгүй**: бүрхүүл нь каталогоор ажилладаг тул цөмийн
нийтэлсэн образ яг таарна. `WEB_IMAGE` нь `go.mod`-ийн цөмийн commit-той ижил
образыг заана — цөмийн хувилбар хөдлөх бүрд хоёулаа хамт хөдөлнө.

## Сервер

Хост: **38.180.117.155**, зөвхөн энэ стек. Стек `/opt/eid-nexus/{src,.env}`,
compose төсөл `eid-nexus`, контейнерууд `gerege_eid_nexus_*`, портууд
`5434 / 8082 / 3008` (бүгд loopback).

```
cd /opt/eid-nexus/src && git pull && ./deploy.sh
```

CI ногоон болмогц `deploy.yml` үүнийг өөрөө хийнэ.

## Лиценз

Apache 2.0 — `LICENSE`.
