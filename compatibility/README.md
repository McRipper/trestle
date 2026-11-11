# Cross-plugin compatibility

This harness runs the seven repository suites, integration flows, Chrome tests
and asset compilation with both Sprockets and Propshaft on Rails 8.1. It uses
the current checkouts, including OTP 0.3.0. Old snapshot worktrees are never
selected automatically.

Place `trestle`, `trestle-auth`, `trestle-auth-otp`, `trestle-search`,
`trestle-active_storage`, `trestle-good_job` and `trestle-mobility` next to each
other. Requirements: Ruby 3.3/3.4, Bundler 2.6.9, PostgreSQL, libvips and Chrome.
The GitHub workflow repeats the complete matrix on both Ruby versions.

```sh
trestle/compatibility/bin/run install
trestle/compatibility/bin/verify
```

The runner installs test gems under `.gems`, disables coverage uploads, creates
an isolated PostgreSQL cluster under `tmp/postgres` and stops it when finished.
It creates only `trestle_rails81_test` and `trestle_otp_test` databases. Do not
point this harness at an application's database: the integration tests reset
their test tables. Existing application databases are not upgraded by this suite.

Overrides: `TRESTLE_WORKSPACE` selects the parent directory of the repositories;
`TRESTLE_OTP_PATH` explicitly selects a different OTP checkout; `PG_BINDIR` selects
PostgreSQL binaries; `TRESTLE_PG_PORT` changes the default 55432 test port;
`TRESTLE_GEM_HOME` selects an existing compatible gem cache. `RBENV_VERSION` selects
a locally installed Ruby when using rbenv. Otherwise the Ruby already in PATH is
used, as in GitHub Actions.

For externally managed test PostgreSQL instances, set both `DATABASE_URL` and
`OTP_TEST_DATABASE_URL` to the two isolated databases named above. The runner
does not stop an externally managed server. `RUN_BROWSER_TESTS=0` skips Chrome
explicitly; the default and CI always run it.

`logs/` contains individual suite results. `revisions.json` records the actual
commit, branch and gem version of each checkout, Ruby and Rails. The runner
fails if repository revisions change during the tests. Empty test suites fail
the summary check too. A success message is emitted only after all enabled
checks, compilation and PostgreSQL OTP concurrency pass.

Coverage includes login/logout, enrollment and one-use recovery codes, the
GoodJob mount while an OTP challenge is pending, actual queued jobs on PostgreSQL,
search, translated fields, single/multiple direct uploads, deletion and libvips
image previews. Chrome runs with CSRF protection enabled and checks JavaScript
errors. The plugin's own tests cover integer/UUID attachment identifiers and the
atomic consumption of OTP/recovery codes is verified by parallel DB connections.

The application upgrade instructions are in [UPGRADING.md](UPGRADING.md).
