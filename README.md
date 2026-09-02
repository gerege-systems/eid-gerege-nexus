# eID Gerege

**eid.gerege.mn** — Gerege Nexus платформын нэг байрлуулалт (distribution).
Иргэн өөрийн **eID Mongolia** цахим үнэмлэхээр нэвтэрдэг, өөрийн бааз, өөрийн
нэвтрэлттэй бие даасан суулгац.

Энэ репод **цөмийн код байхгүй**. `go.mod`-ийн нэг мөр л бүхэл түүх нь:

```
github.com/gerege-systems/open-gerege-nexus/backend
```

Энд байх зүйл нь энэ бүтээгдэхүүний өөрийн апп-ууд (`modules/`), өөрийн
native клиентүүд (`native-apps/`) бөгөөд репо нь
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
| `deploy/docker-compose*.yml` | дөрвөн стек — доорх «Стекүүд» |
| `deploy/monitoring/` | Prometheus + 37 дүрэм, Alertmanager, Loki, Tempo, Alloy, Grafana |
| `deploy/{monitor,dwh,backups}-landing/` | туслах домэйнуудын статик хуудас |
| `deploy/scripts/` | `backup.sh`, `tls-expiry.sh` (cron), `setup_monitor_branding.sh` |
| `deploy.sh` | сервер дээрх rollout — барих, солих, шалгах |
| `nginx/` | vhost бүр: үндсэн, консол, ажиглалт, алдаа, dwh, нөөцлөлт, төхөөрөмжийн шугам |
| `native-apps/` | macOS, Windows, iOS, Android клиент — `desktop.`/`mobile.` шугам |
| `brand/` | бичвэр дарж бичих цэг (`copy.json`) — ихэвчлэн хоосон |
| `.env.example` | `/opt/eid-nexus/.env`-ийн хэлбэр |

Native клиентүүд нь цөмийн бүрхүүлийн код: шугам (`*.eid.gerege.mn`), багц ID
(`mn.gerege.eid.*`), харагдах нэр (**eID Gerege**) гурав нь энэ
бүтээгдэхүүнийх, эх код нь платформынх. `kiosk`/`pos` build нь компайл
хийгддэг ч тэдний хаяг АСААГҮЙ тул түгээхгүй — дэлгэрэнгүйг
`native-apps/README.md`.

Frontend-ийг **барихгүй**: бүрхүүл нь каталогоор ажилладаг тул цөмийн
нийтэлсэн образ яг таарна. `WEB_IMAGE` нь `go.mod`-ийн цөмийн хувилбарын
commit-ыг заана — хоёулаа хамт хөдөлнө.

Тэр образ нь **ghcr.io дээр private** бөгөөд байгууллагын бодлого public
болгохыг хаасан. Тиймээс хост нэг удаа нэвтэрсэн байх ёстой:

```
gh auth token | ssh eid-gerege 'docker login ghcr.io -u <хэрэглэгч> --password-stdin'
```

Токен нь `/home/deploy/.docker/config.json` дотор base64-оор хэвтэнэ. Хугацаа
нь дуусвал rollout «denied» гэж хэлнэ — `deploy.sh` дээрх `pull` нь үхлийн
шалтгаан биш тул хостод байгаа образ дээр ажиллаж үлдэнэ.

## Сервер

Хост: **38.180.117.155**, зөвхөн энэ стек. Стек `/opt/eid-nexus/{src,.env}`,
compose төсөл `eid-nexus`, контейнерууд `gerege_eid_nexus_*`, портууд бүгд
loopback (доорх «Домэйнууд» хэсэг).

```
cd /opt/eid-nexus/src && git pull && ./deploy.sh
```

Ажиглалт, алдааны хөтлөлт нь энэ тушаалд ОРООГҮЙ — тэдгээр өөрийн стектэй
(доорх «Стекүүд»). Тиймээс тэдний нууц үгс `.env`-д байхгүй байсан ч платформын
rollout хэвийн ажиллана.

CI ногоон болмогц `deploy.yml` үүнийг өөрөө хийнэ.

## Домэйнууд

Платформ нь `eid.gerege.mn`-ээр л дуусдаггүй. Цөмийг тойрсон чадварууд бүгд энэ
байрлуулалтын нэр, өнгө, нэвтрэлтийн доор ажиллана — өөр компанийн нэвтрэх
дэлгэц рүү үсэрдэг холбоос энд байхгүй.

| Домэйн | Юу вэ | Порт (loopback) |
|---|---|---|
| `eid.gerege.mn` | бүрхүүл ба API | 3008 / 8082 |
| `admin.eid.gerege.mn` | операторын консол | 3008 / 8082 |
| `monitor.eid.gerege.mn` | landing + Grafana (`/grafana/`) + Alertmanager | 3009 / 9093 |
| `errors.eid.gerege.mn` | GlitchTip — алдааны хөтлөлт | 8000 |
| `dwh.eid.gerege.mn` | дата агуулахын зураглал | 3018 |
| `backups.eid.gerege.mn` | нөөцлөлтийн журам | 3019 |
| `desktop.` / `mobile.eid.gerege.mn` | native клиентүүдийн шугам | 3008 / 8082 |

Дотоод: Prometheus 9091, Loki 3100, Tempo 3200 / 4318, Alloy 12345,
node-exporter 9100, cadvisor 8085, postgres-exporter 9187.

## Стекүүд

Дөрвөн compose төсөл. Тусдаа байгаа нь цөмийнхтэй ижил шалтгаантай: ажиглалт
бүхэлдээ унасан ч платформ мэдэхгүй, `down` нь ямар ч цагт аюулгүй, мөн
платформын rollout бүр арван таван ажиглалтын контейнерийг дахин асаахгүй —
тэр нь яг тэдний ажиглах ёстой мөчид тэднийг сохлох байв.

| Файл | Юу асаадаг | Заавал орчин |
|---|---|---|
| `docker-compose.yml` | postgres, migrate, backend, бүрхүүл | `EID_NEXUS_POSTGRES_PASSWORD`, `SSO_DEFAULT_CLIENT_SECRET`, `WEB_IMAGE` |
| `docker-compose.sites.yml` | dwh, backups хуудас | — |
| `docker-compose.monitoring.yml` | Prometheus, Alertmanager, Loki, Tempo, Alloy, Grafana, гурван exporter | `GRAFANA_ADMIN_PASSWORD`, `MONITORING_DB_PASSWORD` |
| `docker-compose.glitchtip.yml` | GlitchTip + өөрийн Postgres, Redis | `GLITCHTIP_DB_PASSWORD`, `GLITCHTIP_SECRET_KEY` |

`deploy.sh` нь эхний хоёрыг л хөдөлгөнө. Сүүлийн хоёр нь өөрийн амьдралтай:

```
docker compose -f deploy/docker-compose.monitoring.yml --env-file ../.env up -d
docker compose -f deploy/docker-compose.glitchtip.yml  --env-file ../.env up -d
```

### Ажиглалт

Гурван эх сурвалж, нэг цонх: **хэмжүүр** (Prometheus, 60 хоног), **лог** (Loki,
31 хоног), **trace** (Tempo, 72 цаг, 10% түүвэр). Гурвуулаа хоорондоо
холбогдсон — логийн мөрөн дээрх `trace_id` нь trace руу, trace нь тэр агшны лог
ба тэр үйлчилгээний RED хэмжүүр рүү хөтөлнө. Тэр эргэлт нь гурвыг зэрэг
ажиллуулах бүх учир шалтгаан.

Долоон самбар: API тойм, Инфраструктур, Логууд, Аюулгүй байдал, Тэсвэрлэлт,
Гадаад системүүд, Мониторингийн эрүүл мэнд.

**Гучин долоон дохионы дүрэм**, хоёр зэрэглэл. `page` нь тохируулсан суваг бүр
рүү очиж цаг тутам давтагдана; `ticket` нь и-мэйлээр л явж дөрвөн цаг тутам —
зэрэглэлийн салангид байдлын учир нь тэдний нэг нь өглөө хүртэл хүлээж болно
гэдэгт. Суваг тохируулаагүй бол дохио асаж, Alertmanager болон Grafana дээр
харагдаж, хаашаа ч илгээгдэхгүй; хагас бөглөсөн суваг нь асахаас татгалзсан
контейнер байх байсан бөгөөд `render-config.sh` яг үүнээс сэргийлдэг.

Нэвтрэлт нь энэ суулгацын **өөрийн** OIDC provider — платформын админ нь
Grafana-ийн сервер админ, бусад нь уншина. Grafana-ийн дотоод админ хэвээр
байгаа нь санаатай: унасан танигч нь нээгдэхгүй ажиглалтын стек болох ёсгүй.

`postgres_exporter` нь `monitoring` role-оор холбогдоно — superuser-ээр биш.
Цөмийн 00044 миграц тэр role-ыг **нууц үггүй** үүсгэдэг (миграц бол репод
хадгалагддаг файл), тиймээс нэг удаа гараар өгнө:

```
docker exec -i gerege_eid_nexus_postgres psql -U postgres -d platform_db \
  -c "ALTER ROLE monitoring WITH PASSWORD '<generated>'"
```

Grafana OSS-д white labeling байхгүй тул брэндлэлт нь nginx дээр хийгдэнэ.
Хост дээр нэг удаа, дараа нь **Grafana шинэчлэх бүрд**:

```
deploy/scripts/setup_monitor_branding.sh
```

Скрипт нь идемпотент бөгөөд өөрийгөө домэйнээр дамжуулан шалгадаг. Grafana-ийн
chunk-ийн hash өөрчлөгдөхөд орлуулалт таарахаа больж швед хэл эргэж ирнэ — өөр
юу ч эвдрэхгүй, тэр нь тэмдэг.

### Алдааны хөтлөлт

GlitchTip нь Sentry протоколоор ярина: `SENTRY_DSN` (backend) ба
`FRONTEND_SENTRY_DSN` (бүрхүүл). Аль ч тал нь GlitchTip-д тусгайлан бичигдээгүй
— hosted Sentry-ийн DSN нь энэ стекийг бүхэлд нь кодын өөрчлөлтгүйгээр орлоно.

Өөрийн Postgres, өөрийн Redis: алдаа хөтлөгч нь stack trace ба үйл явдлын
агуулгыг хадгалдаг бөгөөд түүнийг иргэдийн өгөгдөлтэй нэг кластерт тавих нь
өөр хүний миграцаар удирдагдах схем нэмэх хэрэг.

Нээлттэй бүртгэл байхгүй. Эхний хэрэглэгч:

```
docker exec -it gerege_eid_nexus_glitchtip_web ./manage.py createsuperuser
```

### Нөөцлөлт

Хоёр cron ажил, аль нь ч compose-ийн үйлчилгээ биш:

```
15 3 * * * /opt/eid-nexus/src/deploy/scripts/backup.sh      >> /var/log/eid-backup.log 2>&1
30 4 * * * /opt/eid-nexus/src/deploy/scripts/tls-expiry.sh  >> /var/log/eid-tls-expiry.log 2>&1
```

Нөөцлөлтийн үр дүн хоёр газар бүртгэгдэнэ: консол уншдаг `platform_backups`
хүснэгт, ба Prometheus уншдаг `nexus_backup_*` хэмжүүр. Хоёр дахь нь шөнө дунд
хэн нэгэнд сэрэмжлүүлэг илгээж чадах цорын ганц зам.

`tls-expiry.sh` нь certbot-ын сертификатуудыг уншиж `nexus_tls_not_after_*`
хэмжүүр бичнэ. Түүнгүйгээр `NexusTLSCertificateExpiringSoon` хэзээ ч ажиллахгүй
(цуврал байхгүй) бөгөөд `NexusTLSExpiryUnknown` зургаан цагийн дараа асаад тэр
чигтээ үлдэнэ.

**Өөр байршил руу**: зорилт нь цөмийн ажиллуулдаг обьект сан —
`backups.nexus.gerege.mn`, **өөр машин дээр**. Энэ хост дээр өөрийн MinIO
босгох нь нэг машин дээрх хоёр дахь хуулбар л болно: хүснэгт устгах, буруу
миграц, volume дахин үүсэхээс хамгаална, хостоо алдахаас биш. Тиймээс энэ репод
обьект сангийн compose файл байхгүй — байгаа нэгэн рүү нь `BACKUP_S3_*`-аар
илгээнэ. Хуулбар нь илгээгдэхээсээ өмнө age-ээр шифрлэгдэнэ; хостод зөвхөн
**нийтийн** түлхүүр байна.

### Native клиентүүд

Клиентийн код **энд байна**: `native-apps/` — macOS, Windows (WPF/WebView2),
iOS/iPadOS, Android. Цөмийн бүрхүүлээс хуулж авсан бөгөөд энэ бүтээгдэхүүнийх
болсон нь гурван зүйл: шугам (`desktop.`/`mobile.eid.gerege.mn`), багц ID
(`mn.gerege.eid.*`, Windows дээр `GeregeEID.*`), харагдах нэр (**eID Gerege**).
Эх кодын package нэр (`mn.gerege.nexus`, `GeregeNexusNativeWin`) цөмийнх хэвээр:
бүрхүүл нь Gerege Nexus-ийн бүрхүүл мөн бөгөөд package нэр солих нь хүн ч,
дэлгүүр ч харахгүй зүйлийг л хөдөлгөнө.

Байрлуулалтын тал нь `nginx/device-lines.eid.gerege.mn.conf` ба
`DEVICE_LINE_ORIGINS`. Шугам бүр өөрийн host дээр сууж, тэр host нь `/api/v1`-ийг
энэ backend руу дамжуулдаг тул webview доторх дуудлага same-origin хэвээр байна.

Дараалал: DNS → nginx → certbot → **хамгийн сүүлд** клиентийн доторх хаяг.
Эсрэгээр явбал апп байхгүй host руу чиглэж унана. `kiosk`/`pos` build нь
кодын хувьд бэлэн ч тэр хоёр хаяг АСААГҮЙ тул түгээхгүй
(`native-apps/shared/device_lines.json` → `provisioned: false`).

Нэвтрэх дэлгэцийн **бичвэр** долоон хэл дээрээ eID Gerege гэж хэлнэ.
Орчуулга нь цөмийн `i18n:export-native`-ийн гаралт бөгөөд `{brand}` тэмдэг нь
экспортын мөчид задардаг — тиймээс гараар бүү зас, гараар бүү экспортол:

```
native-apps/sync-i18n.sh ../open-gerege-nexus
```

Скрипт нь цөмийн ажлын модыг хөндөхгүй, дөрвөн хэлбэрийг (JSON, Android XML,
Windows resx, iOS xcstrings) бүгдийг нь бичээд цөмийн анхдагч нэр үлдсэн
эсэхийг шалгана.

**Үлдсэн ганц цоорхой — тэмдэг.** `brand.png`, `AppIcon`, `ic_launcher` бүгд
платформын тэмдэг хэвээр; вэб талд ч `BRAND_LOGO_URL`, `BRAND_ICON_URL`
хоосон. Нэрийг код удирдаж чадна, тэмдгийг чадахгүй — солих ёстой файлуудын
жагсаалт [`native-apps/README.md`](native-apps/README.md)-д.

CI: `.github/workflows/native-clients.yml` дөрвүүлэн компайл хийгдэж байгааг
push, PR бүрд шалгана.

## Лиценз

Apache 2.0 — `LICENSE`.
