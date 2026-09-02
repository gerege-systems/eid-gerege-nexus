#!/usr/bin/env bash
#
# eID Gerege — TLS сертификатын хугацааг хэмжигдэхүүн болгож бичих.
#
# `NexusTLSCertificateExpiringSoon` ба `NexusTLSExpiryUnknown` хоёр дохио
# `nexus_tls_not_after_timestamp_seconds` цувралыг уншдаг. Тэр цуврал нь ямар ч
# exporter-оос ирдэггүй: certbot-ын сертификатууд хостын файлын систем дээр
# байдаг тул хэн нэгэн тэднийг уншиж, node_exporter-ийн textfile хавтас руу
# бичих ёстой. Энэ скрипт тэр ажлыг хийнэ.
#
# Ингэж бичихгүй бол хоёр дохионы эхнийх нь ХЭЗЭЭ Ч ажиллахгүй (цуврал
# байхгүй), хоёр дахь нь 6 цагийн дараа ажиллаад тэр чигтээ асаж үлдэнэ —
# өөрөөр хэлбэл сертификат дуусахыг хэн ч мэдэхгүй.
#
# Cron дээр (өдөрт нэг удаа хангалттай — certbot 30 хоногийн өмнөөс сунгадаг):
#
#   30 4 * * * /opt/eid-nexus/src/deploy/scripts/tls-expiry.sh >> /var/log/eid-tls-expiry.log 2>&1
#
# Тохируулга:
#   CERT_DIR      — certbot-ын live хавтас (анхдагч /etc/letsencrypt/live)
#   TEXTFILE_DIR  — node_exporter-ийн textfile хавтас
#
# root эрхээр ажиллана: /etc/letsencrypt/live нь зөвхөн root-д уншигдана.

set -euo pipefail

CERT_DIR="${CERT_DIR:-/etc/letsencrypt/live}"
TEXTFILE_DIR="${TEXTFILE_DIR:-/var/lib/node_exporter}"
OUT="${TEXTFILE_DIR}/eid_tls.prom"

command -v openssl >/dev/null || { echo "tls-expiry: openssl олдсонгүй" >&2; exit 1; }
[ -d "$TEXTFILE_DIR" ] || { echo "tls-expiry: $TEXTFILE_DIR алга" >&2; exit 1; }

# Атомик бичилт: node_exporter хагас бичигдсэн файлыг уншиж болохгүй бөгөөд
# тэр нь хэмжигдэхүүнийг алдагдуулахаас гадна parse алдаа болж, ТЭР exporter-
# ийн бүх textfile хэмжигдэхүүнийг унагадаг.
tmp="$(mktemp "${OUT}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

{
    echo "# HELP nexus_tls_not_after_timestamp_seconds When this certificate stops being valid"
    echo "# TYPE nexus_tls_not_after_timestamp_seconds gauge"
} > "$tmp"

found=0
for cert in "$CERT_DIR"/*/fullchain.pem; do
    [ -e "$cert" ] || continue
    domain="$(basename "$(dirname "$cert")")"

    # `openssl x509 -enddate` нь "notAfter=Nov 12 09:41:03 2026 GMT" гэж өгнө.
    # Түүнийг epoch болгоно — GNU date. Хөрвүүлэлт унавал ТЭР сертификатыг
    # алгасана: буруу тоо бичих нь юу ч бичихгүй байхаас дор, учир нь тэр нь
    # дохиог чимээгүйхэн хаана.
    end="$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2-)" || continue
    [ -n "$end" ] || continue
    epoch="$(date -d "$end" +%s 2>/dev/null)" || {
        echo "tls-expiry: $domain-ийн огноог уншиж чадсангүй: $end" >&2
        continue
    }

    echo "nexus_tls_not_after_timestamp_seconds{domain=\"${domain}\"} ${epoch}" >> "$tmp"
    found=$((found + 1))
done

# Нэг ч сертификат олдоогүй бол ЮУ Ч БИЧИХГҮЙ. Зөвхөн HELP/TYPE мөртэй файл нь
# `absent()`-ыг хуурч чадахгүй ч, өмнө нь бичигдсэн зөв утгуудыг дарж
# устгана — тэр нь хэмжилтийг чимээгүйхэн алдагдуулах хамгийн шууд зам.
if [ "$found" -eq 0 ]; then
    echo "tls-expiry: $CERT_DIR дотор сертификат олдсонгүй — өмнөх файлыг хэвээр үлдээв" >&2
    exit 1
fi

chmod 0644 "$tmp"
mv -f "$tmp" "$OUT"
trap - EXIT
echo "tls-expiry: ${found} сертификат бичигдэв ($OUT)"
