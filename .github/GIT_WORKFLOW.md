# Git Workflow Guide

This document outlines our Git workflow and best practices for contributing to the project.

## Branch Strategy

We maintain two primary branches:
- `main`: Production-ready code only
- `develop`: Primary integration branch for feature work

### Branch Types
- `feature/*`: New features and non-emergency bug fixes
- `release/*`: Release preparation branches
- `hotfix/*`: Emergency fixes for production issues

## Workflow Guidelines

### Starting New Work
1. Always branch from `develop` for new features:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

### Commit Guidelines
We follow conventional commit messages:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Example:
```
feat: add OAuth2 authentication support
```

### Pull Request Process
1. Keep PRs focused and reasonably sized
2. Include clear description and testing steps
3. Ensure all tests pass
4. Request review from at least one team member
5. Address review feedback promptly

### Merging Guidelines
1. Ensure PR has required approvals
2. All status checks must pass
3. Resolve any conflicts
4. Use "Squash and merge" for feature branches
5. Delete the feature branch after merging

### Release Process
1. Create release branch from develop:
   ```bash
   git checkout -b release/x.y.z develop
   ```
2. Only bug fixes allowed in release branches
3. Merge to main AND develop when ready
4. Tag the release in main

### Hotfix Process
1. Branch from main:
   ```bash
   git checkout -b hotfix/issue-description main
   ```
2. Fix the issue
3. Merge to main AND develop
4. Tag the release

## Code Review Guidelines

### As a Submitter
- Provide clear context
- Self-review your code first
- Keep changes focused
- Test thoroughly
- Respond to feedback constructively

### As a Reviewer
- Review promptly
- Be constructive
- Look for:
  - Functionality
  - Code quality
  - Test coverage
  - Documentation
- Approve only when satisfied

## Best Practices
- Keep commits atomic
- Write clear commit messages
- Always pull before starting new work
- Regularly sync with the base branch
- Delete merged feature branches
