;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; ECOSYSTEM.scm — laniakea

(ecosystem
  (version "1.0.0")
  (name "laniakea")
  (type "project")
  (purpose "*The browser isn't a client — it's a peer node in a distributed system where state flows and converges.*")

  (position-in-ecosystem
    "Part of hyperpolymath ecosystem. Follows RSR guidelines.")

  (related-projects
    (project (name "rhodium-standard-repositories")
             (url "https://github.com/hyperpolymath/rhodium-standard-repositories")
             (relationship "standard")))

  (what-this-is "*The browser isn't a client — it's a peer node in a distributed system where state flows and converges.*")
  (what-this-is-not "- NOT exempt from RSR compliance"))
