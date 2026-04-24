# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.5] - 2026-04-24

### Added
- Release checklist in `README.md` and release validation workflow for tag builds.
- Public-maintainer docs: `CONTRIBUTING.md`, `SECURITY.md`, and release template.

### Changed
- CI now also runs on tag pushes.
- API hardening pass to reduce non-essential public surface.

### Fixed
- Cross-target symbol visibility for `ProwlShakeMonitor` in iOS package builds.
- Formatter test expectations aligned with current share-text format.

## [1.0.3] - 2026-04-24

### Added
- Sensitive data masking toggle (default OFF).
- URLSession snapshot support and integration helpers for stream-backed bodies.
- Optional integration helpers for Alamofire and Moya body snapshot capture.

### Changed
- Request body capture path aligned with netfox-style safe behavior.
- UI styling refreshed to match Prowl branding while keeping improved data presentation.

### Fixed
- Multiple Swift 6 concurrency and selector ambiguity issues in runtime integrations.
