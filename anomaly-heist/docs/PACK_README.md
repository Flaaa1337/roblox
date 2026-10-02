# ANOMALY HEIST - Worldwide Claude Build Pack

This pack provides an implementation specification for a Roblox game. It does not contain an implemented game or verified gameplay tests.

## Contents

- `CLAUDE.md`: compact project instructions for Claude Code.
- `docs/BUILD_SPEC.md`: complete gameplay, worldwide localization, art, architecture, security, production, and acceptance specification.
- `references/roblox_style_reference.png`: optional concept-art reference, not an actual gameplay screenshot.
- `START_PROMPT.txt`: a ready-to-use implementation prompt.

## Use with Claude Code or another file-editing coding environment

Place these files in the intended project directory, preserving any existing project files. If a `CLAUDE.md` already exists, merge the instructions deliberately rather than replacing it blindly.

Open that directory in the coding environment and submit the text from `START_PROMPT.txt`. Claude should inspect the actual tools and files, read the detailed brief, and start M0.

The brief does not assume VS Code or an installed Rojo CLI. Roblox Studio configuration and tests remain explicit tasks unless the coding environment actually has authorized Studio access.

## Use in a chat without project access

Upload `docs/BUILD_SPEC.md` and optionally the reference image. Submit the start prompt, changing its first sentence to refer to the uploaded specification. Request complete files with exact paths; do not treat a chat-only response as a tested Studio implementation.

## Worldwide scope

US English is the source. The specification includes all 50 locale IDs in the Roblox registry checked on October 2, 2026, plus requirements to refresh that registry, track translation quality, handle fallback, test scripts and layouts, use appropriate pricing displays, and schedule globally accessible events.

Locale coverage is a build target, not a claim that translations already exist. Platform availability and per-player eligibility are separate from language support.

## What should happen first

The first implementation response should inspect the environment and begin the reproducible project foundation. The first visual milestone is a real, walkable Roblox space with eight base plots and a beginner expedition area, followed by a complete three-creature gameplay loop.

References for changing platform behavior are in Section 29 of `docs/BUILD_SPEC.md`.
