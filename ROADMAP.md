# Roadmap

## Completed

- [x] Core domain-based analysis system
- [x] Transcript parsing (UserEvent, AssistantEvent, SystemEvent, ResultEvent)
- [x] Pattern detection (repeated commands, user directives, errors)
- [x] Claude Code automation domain with system prompts
- [x] Dart 3.10 SDK with strict linting (50+ rules)
- [x] GitHub Actions CI/CD (format, analyze, test, coverage)
- [x] Automated pub.dev publishing workflow
- [x] Dependabot for dependency updates
- [x] Codecov integration

## In Progress

- [ ] Background daemon mode (`start` command)
- [ ] Git worktree isolation for changes
- [ ] Automatic PR creation
- [ ] Status reporting (`creep` command)

## Pre-Release Checklist

- [ ] First manual publish to pub.dev (`dart pub publish`)
- [ ] Configure automated publishing on pub.dev admin:
  - [ ] Enable "Automated publishing from GitHub Actions"
  - [ ] Set repository: `tylerjewell/claude-code-creeper`
  - [ ] Set tag pattern: `v{{version}}`
- [ ] Verify GitHub Actions CI workflow runs on push
- [ ] Verify Dependabot creates PRs for dependency updates

## Future

- [ ] Multi-project support
- [ ] Custom domain plugins
- [ ] Learning from PR feedback (accepted vs rejected)
- [ ] Integration with GitHub Issues
- [ ] Web dashboard for monitoring

## Releasing

Tag and push to trigger automated publish:

```bash
# Update version in pubspec.yaml, then:
git tag v0.2.0
git push origin v0.2.0
```
