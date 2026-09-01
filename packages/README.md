# Shared Packages

This directory contains shared code used across multiple applications.

## Structure

```
packages/
├── api-types/        # Shared TypeScript API types (for Nuxt apps)
├── api-client/       # Shared TypeScript API client (for Nuxt apps)
└── ...
```

## Rules

1. Only create a shared package when there is a concrete need from at least two applications.
2. Shared packages must not contain business logic — only types, contracts, and utilities.
3. Flutter shares types via OpenAPI code generation, not via TypeScript packages.
4. Each package must have its own `README.md` and `package.json` (for TS packages).
5. Do not create a package without documenting the need in an ADR.

## Status

No shared packages have been created yet. They will be added when concrete cross-application needs are identified.
