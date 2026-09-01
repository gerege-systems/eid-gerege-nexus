# eID Gerege's own image.
#
# Two binaries the deployment needs at every boot — this product's server and
# the platform's migration runner — plus two it needs from a shell. All of them
# are built from the exact core version go.mod pins, so the schema an image
# applies and the apps it offers are the ones the code in it was written
# against. A module's own migrations would not be: they travel inside the
# module, through nexus.Migrations.

FROM golang:1.26-alpine AS build

RUN apk add --no-cache git ca-certificates

WORKDIR /src

# Dependencies first, so a change to our own code does not re-download the core.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# What this build tells an app store it is.
#
# Derived from the core version go.mod pins rather than passed in, because it is
# not a choice: PlatformVersion is what every manifest's `"platform": ">=1.0.0"`
# is checked against, and the honest answer is the version of the platform
# actually compiled into this image. Left to a build argument it defaults to
# the source default, and the instance then refuses every manifest it ships
# with — it cannot read its own catalogue, so it will not start.
#
# Which package holds it is asked rather than assumed. PlatformVersion moved
# from internal/platform to internal/kernel/config after the core's v1.13.0,
# and `-X` naming a symbol that does not exist is **silently ignored** by the
# linker: a stale path builds cleanly, produces an image that reports the
# default, and that image then never comes up. Nothing in the build log says
# so. The two candidates are probed in order and a core with neither fails the
# build here, loudly.
#
# `${core#v}` strips the leading v and `%%-*` strips a pseudo-version's
# suffix. That second one is not cosmetic: go.mod pins the core at a commit
# rather than a tag while its main waits for v2.0.0, so `go list` answers
# 1.16.1-0.20260901072345-a840514583b1 — a semver PRERELEASE, which orders
# BELOW 1.16.1 and would fail a manifest asking for it.
RUN core=$(go list -m -f '{{.Version}}' github.com/gerege-systems/open-gerege-nexus/backend) \
    && version=${core#v} \
    && version=${version%%-*} \
    && base=github.com/gerege-systems/open-gerege-nexus/backend/internal \
    && for pkg in kernel/config platform; do \
         if go list "$base/$pkg" >/dev/null 2>&1; then sym="$base/$pkg.PlatformVersion"; break; fi; \
       done \
    && { [ -n "${sym:-}" ] || { echo "no PlatformVersion package in ${core}"; exit 1; }; } \
    && echo "building as platform ${version} (${sym##*/internal/})" \
    && CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags="-w -s -X ${sym}=${version}" \
    -o /bin/eidnexus .

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-w -s" \
    -o /bin/migrate github.com/gerege-systems/open-gerege-nexus/backend/cmd/migrate

# The console's first operator, for the deployments the wizard cannot reach.
# The wizard opens the console as its last step, but only while the deployment
# has no organisation: its token dies the moment one exists.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-w -s" \
    -o /bin/operator-bootstrap github.com/gerege-systems/open-gerege-nexus/backend/cmd/operator-bootstrap

# The second organisation, and every one after it, from a shell. The console
# screen needs an operator session; this does not.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-w -s" \
    -o /bin/tenant-bootstrap github.com/gerege-systems/open-gerege-nexus/backend/cmd/tenant-bootstrap

# The platform's migration files, which are data in the module rather than code.
# The path carries the version, so this reads it back rather than guessing.
RUN core=$(go list -m -f '{{.Dir}}' github.com/gerege-systems/open-gerege-nexus/backend) \
    && mkdir -p /out/db && cp -r "$core/db/migrations" /out/db/migrations \
    && chmod -R u+w /out/db

# The catalogue.
#
# It cannot come out of the module cache like the migrations do: the Go module
# is rooted at the core's `backend/` and `catalog/` sits beside it, outside the
# module. So it comes from the ref `go list` just reported — the alternative is
# committing the platform's entries here, where they go stale the day the core
# is bumped.
#
# A pseudo-version has no tag to ask for, so the archive is fetched by the
# commit the pseudo-version ends in. Same file either way: GitHub serves
# `archive/<ref>.tar.gz` for a tag or a sha.
#
# This repository carries no apps of its own, so there is nothing to merge in.
# The day the first module lands, this becomes the jq merge the sibling
# distributions run — an instance whose binary carries an app its catalogue
# does not name refuses to start.
RUN core=$(go list -m -f '{{.Version}}' github.com/gerege-systems/open-gerege-nexus/backend) \
    && case "$core" in \
         *-*) ref="${core##*-}" ;; \
         *)   ref="refs/tags/backend/${core}" ;; \
       esac \
    && wget -qO- "https://github.com/gerege-systems/open-gerege-nexus/archive/${ref}.tar.gz" \
    | tar -xz -C /tmp \
    && cp -r /tmp/open-gerege-nexus-*/catalog /out/catalog \
    && test -f /out/catalog/apps.json

FROM alpine:3.22

RUN apk add --no-cache ca-certificates tzdata wget \
    && adduser -D -u 10001 eidnexus

WORKDIR /app

COPY --from=build /bin/eidnexus /app/eidnexus
COPY --from=build /bin/migrate  /app/migrate
COPY --from=build /bin/operator-bootstrap /app/operator-bootstrap
COPY --from=build /bin/tenant-bootstrap   /app/tenant-bootstrap
COPY --from=build /out/db       /app/db
COPY --from=build /out/catalog  /app/catalog

USER eidnexus
EXPOSE 8080

CMD ["/app/eidnexus"]
