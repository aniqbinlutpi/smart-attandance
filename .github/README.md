# Smart Attendance CI/CD Pipeline

Professional-grade CI/CD pipeline with Discord notifications for the Smart Attendance Flutter application.

## 🎯 Quick Links

- **[Quick Setup Guide](QUICK_SETUP.md)** - Get started in 5 minutes
- **[Full Documentation](CICD.md)** - Comprehensive guide
- **[Pipeline Overview](OVERVIEW.md)** - Visual workflow diagrams
- **[PR Template](PULL_REQUEST_TEMPLATE.md)** - Contribution guidelines

## 📊 Pipeline Status

[![CI Pipeline](https://github.com/aniqbinlutpi/smart-attandance/actions/workflows/ci.yml/badge.svg)](https://github.com/aniqbinlutpi/smart-attandance/actions/workflows/ci.yml)
[![CD Pipeline](https://github.com/aniqbinlutpi/smart-attandance/actions/workflows/cd.yml/badge.svg)](https://github.com/aniqbinlutpi/smart-attandance/actions/workflows/cd.yml)
[![Security Scan](https://github.com/aniqbinlutpi/smart-attandance/actions/workflows/security-scan.yml/badge.svg)](https://github.com/aniqbinlutpi/smart-attandance/actions/workflows/security-scan.yml)

## ✨ Features

### 🔄 Continuous Integration
- ✅ Automated code quality checks
- ✅ Static analysis with strict rules
- ✅ Unit & widget tests with coverage
- ✅ Multi-platform builds (Android, iOS, Web)
- ✅ Real-time Discord notifications

### 🚀 Continuous Deployment
- ✅ Automated release builds
- ✅ GitHub releases with artifacts
- ✅ APK and AAB generation
- ✅ Release notifications

### 🔐 Security & Compliance
- ✅ Weekly security scans
- ✅ Secret detection
- ✅ Dependency auditing
- ✅ License compliance checks

### 🤖 Automation
- ✅ PR auto-labeling
- ✅ Automated dependency updates
- ✅ Code owner assignments
- ✅ Coverage reporting

## 🚀 Getting Started

### Prerequisites
- GitHub repository
- Discord server with webhook access

### Setup (5 minutes)

1. **Create Discord Webhook**
   - Server Settings → Integrations → Webhooks → New Webhook
   - Copy the webhook URL

2. **Add GitHub Secret**
   - Repository Settings → Secrets → New secret
   - Name: `DISCORD_WEBHOOK_URL`
   - Value: Your webhook URL

3. **Push to GitHub**
   ```bash
   git add .github/
   git commit -m "ci: add professional CI/CD pipeline"
   git push origin main
   ```

4. **Verify**
   - Check GitHub Actions tab
   - Look for Discord notification

**That's it!** Your pipeline is now active. 🎉

For detailed instructions, see [Quick Setup Guide](QUICK_SETUP.md).

## 📁 Structure

```
.github/
├── workflows/
│   ├── ci.yml              # Main CI pipeline
│   ├── cd.yml              # Release pipeline
│   ├── pr-checks.yml       # PR validation
│   ├── auto-label.yml      # Auto-labeling
│   └── security-scan.yml   # Security scans
├── CICD.md                 # Full documentation
├── OVERVIEW.md             # Visual overview
├── QUICK_SETUP.md          # Setup guide
├── PULL_REQUEST_TEMPLATE.md
├── CODEOWNERS
├── dependabot.yml
└── labeler.yml
```

## 🎯 Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **CI Pipeline** | Push, PR | Code quality, tests, builds |
| **CD Pipeline** | Version tags | Release builds, GitHub releases |
| **PR Checks** | Pull requests | Strict PR validation |
| **Auto Label** | PR events | Automatic labeling |
| **Security Scan** | Weekly, Push | Security & compliance |

## 📊 Quality Standards

### Code Quality
- Zero analyzer warnings/infos
- 100% formatted code
- All tests passing
- Successful builds

### PR Requirements
- Semantic commit format
- Code review approval
- All checks passing
- No security issues

### Security
- No hardcoded secrets
- Updated dependencies
- License compliance
- Regular audits

## 📢 Discord Notifications

Get real-time updates for:
- ✅ CI/CD pipeline status
- ✅ Pull request checks
- ✅ Release deployments
- ✅ Security scan results

Example notification:
```
✅ CI Pipeline - Success
Repository: aniqbinlutpi/smart-attandance
Branch: main

Job Results:
• Code Quality: ✅ success
• Tests: ✅ success
• Android Build: ✅ success
• iOS Build: ✅ success
• Web Build: ✅ success
```

## 🛠️ Customization

### Change Flutter Version
Edit `env.FLUTTER_VERSION` in workflow files:
```yaml
env:
  FLUTTER_VERSION: '3.24.0'
```

### Modify Notifications
Edit Discord notification steps in workflows to customize messages.

### Add Platforms
Add build jobs for additional platforms in `ci.yml`.

## 📚 Documentation

- **[CICD.md](CICD.md)** - Comprehensive CI/CD documentation
- **[OVERVIEW.md](OVERVIEW.md)** - Visual workflow diagrams
- **[QUICK_SETUP.md](QUICK_SETUP.md)** - 5-minute setup guide

## 🆘 Troubleshooting

### Discord not working?
- Verify webhook URL
- Check secret name: `DISCORD_WEBHOOK_URL`
- Ensure webhook is enabled

### Builds failing?
- Check Flutter version
- Review error logs
- Run locally first

### Need help?
- Check GitHub Actions logs
- Review Discord notifications
- Open an issue

## 🎓 Best Practices

### Development
```bash
# Before committing
dart format .
flutter analyze
flutter test
```

### Pull Requests
- Use semantic commit format
- Keep PRs small and focused
- Add tests for new features
- Update documentation

### Releases
```bash
# Create a release
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

## 📈 Metrics

### Generated Reports
- Analysis reports (30 days)
- Coverage reports (30 days)
- Security reports (90 days)
- Build artifacts (7-90 days)

### Automation Stats
- ✅ 100% automated testing
- ✅ Multi-platform builds
- ✅ Zero-touch releases
- ✅ Real-time notifications

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Push and create a PR
5. Wait for CI checks
6. Get review and merge

See [PR Template](PULL_REQUEST_TEMPLATE.md) for guidelines.

## 📝 License

This CI/CD configuration is part of the Smart Attendance project.

---

**Made with ❤️ for professional Flutter development**

**Status**: ✅ Production Ready | **Version**: 1.0.0 | **Last Updated**: 2025-12-14
