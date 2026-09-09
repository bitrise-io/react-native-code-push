### Code review instructions

This repo has lots of legacy code and questionable patterns. Do not follow or advocate patterns just because they exist somewhere else. Be critical, consider modern best practices.

When in doubt about user-facing behavior or the wider product surface, check `./docs` and https://docs.bitrise.io/en/release-management/codepush/about-codepush

### High-value review areas

- Package install, live bundle reload, and rollback handling (Android + iOS). These are the critical codepaths that should not crash or fail.
- JS public API compatibility (enforced mechanically via `./api-compat`), but it might not catch everything.

### Low-value review areas

- Anything that CI pipelines and tests catch automatically.
