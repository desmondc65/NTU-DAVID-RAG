# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Rewrote `README.md` to reflect completed Phase 1/2/3 implementation and current module ownership:
	- phase 1 in `utils/s1_data_ingestion`
	- phase 2 in `utils/s2_embedding`
	- phase 3 in `utils/s3_RAG`
	- orchestration in `utils/orchestrator`
- Added precise operations documentation for running and maintaining services:
	- local LLM service in `docker/local_llm`
	- full RAG service in `docker/RAG`
	- environment variables, startup order, API endpoints, and maintenance runbook.

## [1.0.1] - 2026-01-18

### Added

- paper2code implemented with gemini, ran with 5 available papers.

## [1.0.0] - 2026-01-12

### Added

- Initial release.
