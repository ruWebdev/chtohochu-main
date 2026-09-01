## Description

<!-- Brief description of the change -->

## Type of Change

- [ ] feat: new feature
- [ ] fix: bug fix
- [ ] refactor: code refactoring
- [ ] chore: maintenance/tooling
- [ ] docs: documentation
- [ ] test: tests
- [ ] build: build system
- [ ] ci: CI configuration

## Affected Applications

- [ ] Flutter client (`apps/client`)
- [ ] Public web (`apps/public-web`)
- [ ] Seller (`apps/seller`)
- [ ] Admin (`apps/admin`)
- [ ] Backend (`backend/api`)
- [ ] Infrastructure (`infrastructure`)
- [ ] Documentation (`docs`)

## Architecture Compliance

- [ ] I have read `AGENTS.md` before making architectural changes
- [ ] I have read relevant `docs/` before implementing
- [ ] No new forbidden practices introduced (see AGENTS.md §16)
- [ ] No BLoC/GetIt/Equatable introduced in Flutter
- [ ] No business logic in controllers or UI widgets
- [ ] No secrets committed

## Testing

- [ ] `flutter analyze` passes (if Flutter changed)
- [ ] `php artisan test` passes (if backend changed)
- [ ] `npm run typecheck` passes (if web changed)
- [ ] Tests added for new functionality

## Documentation

- [ ] Updated relevant `docs/` files if architectural behaviour changed
- [ ] Created/updated ADR if an architectural decision was made
