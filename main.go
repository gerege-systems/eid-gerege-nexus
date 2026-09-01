/*
 * eID Gerege
 * Copyright (c) 2026 Gerege Systems Development Team, Gerege Nomadica Foundation.
 * Distributed under the Apache 2.0 License.
 */

// Command eidnexus runs the Gerege Nexus platform as the eID Gerege
// distribution: the citizen-facing installation at eid.gerege.mn that
// identifies people with their eID Mongolia credential.
//
// There is no core code in this repository — go.mod's one line is the whole of
// it. What will live here is this product's own apps, under modules/, and the
// repository is Level 2 from the first commit precisely so that adding the
// first of them is a change to this file rather than a migration of the
// deployment (core docs/ECOSYSTEM_GIT_STRATEGY.md, §1).
//
// It identifies people itself: no SSO_CLIENT_ISSUER, its own sign-in, its own
// database, and EID_RP_* pointing at eidmongolia.mn. That is a deployment
// decision and nothing in this file knows about it — see
// deploy/docker-compose.yml.
//
// It carries no app modules yet. A platform that boots with zero business apps
// is the ecosystem's baseline, not a placeholder: sign-in, tenants, the store
// and the rails are the platform's and are all here. Modules go in the
// Options.Modules callback and nowhere else — logic written in this file
// instead of in a module is logic no other deployment can have and no test can
// reach.
package main

import (
	"log/slog"
	"os"

	"github.com/gerege-systems/open-gerege-nexus/backend/pkg/host"
)

func main() {
	// The error is checked and the exit code is the point: a distribution that
	// cannot start must not exit 0 and read as a clean shutdown to whatever is
	// supervising it.
	if err := host.Run(host.Options{}); err != nil {
		slog.Error("eid gerege stopped", "error", err)
		os.Exit(1)
	}
}
