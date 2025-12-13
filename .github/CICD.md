# CI/CD Pipeline Documentation

This document describes the CI/CD pipeline setup for the Smart Attendance Flutter application.

## 📋 Overview

The project uses GitHub Actions for automated CI/CD with three main workflows:

1. **CI Pipeline** (`ci.yml`) - Continuous Integration for all pushes and PRs
2. **CD Pipeline** (`cd.yml`) - Continuous Deployment for releases
3. **PR Checks** (`pr-checks.yml`) - Strict validation for pull requests

## 🔧 Setup Instructions

### 1. Discord Webhook Configuration

To receive Discord notifications, you need to set up a webhook:

1. **Create Discord Webhook:**
   - Go to your Discord server
   - Navigate to Server Settings → Integrations → Webhooks
   - Click "New Webhook"
   - Name it (e.g., "Smart Attendance CI/CD")
   - Select the channel for notifications
   - Copy the Webhook URL

2. **Add to GitHub Secrets:**
   - Go to your GitHub repository
   - Navigate to Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `DISCORD_WEBHOOK_URL`
   - Value: Paste your Discord webhook URL
   - Click "Add secret"

### 2. Optional: Android Signing Configuration

For release builds, you may want to configure Android signing:

1. Create a keystore file:
   ```bash
   keytool -genkey -v -keystore android-release.keystore -alias smart-attendance -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Add to GitHub Secrets:
   - `ANDROID_KEYSTORE_BASE64` - Base64 encoded keystore file
   - `ANDROID_KEY_ALIAS` - Key alias
   - `ANDROID_KEY_PASSWORD` - Key password
   - `ANDROID_STORE_PASSWORD` - Store password

## 🚀 Workflows

### CI Pipeline (`ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual workflow dispatch

**Jobs:**

1. **Code Quality & Analysis**
   - Dart code formatting verification
   - Static analysis with strict rules (`--fatal-infos --fatal-warnings`)
   - Dependency vulnerability checks
   - Generates analysis report

2. **Unit & Widget Tests**
   - Runs all tests with coverage
   - Generates HTML coverage report
   - Uploads coverage artifacts

3. **Build Android**
   - Builds debug APK
   - Analyzes APK size
   - Uploads APK artifact

4. **Build iOS**
   - Builds iOS app (no codesign)
   - Verifies build success

5. **Build Web**
   - Builds web application
   - Analyzes build size
   - Uploads web build artifact

6. **Discord Notification**
   - Sends comprehensive status update to Discord
   - Includes all job results and links

### CD Pipeline (`cd.yml`)

**Triggers:**
- Push of version tags (e.g., `v1.0.0`)
- Manual workflow dispatch

**Jobs:**

1. **Build Release**
   - Builds release APK
   - Builds App Bundle (AAB) for Play Store
   - Analyzes build sizes
   - Uploads artifacts

2. **Create GitHub Release**
   - Creates GitHub release with tag
   - Attaches APK and AAB files
   - Generates release notes

3. **Discord Notification**
   - Announces new release
   - Provides download links

### PR Checks (`pr-checks.yml`)

**Triggers:**
- Pull request opened, synchronized, or reopened
- Only runs on non-draft PRs

**Jobs:**

1. **PR Validation**
   - Validates PR title follows semantic commit format
   - Checks PR size (warns if too large)

2. **Code Quality**
   - Strict formatting checks
   - Static analysis
   - Checks for TODO comments

3. **Security Checks**
   - Scans for hardcoded secrets
   - Dependency audit

4. **Test Coverage**
   - Runs tests with coverage
   - Comments coverage on PR
   - Uploads coverage report

5. **Build Verification**
   - Verifies Android build succeeds
   - Checks APK output

6. **Discord Notification**
   - Sends PR check results to Discord

## 📊 Quality Standards

The CI pipeline enforces the following quality standards:

### Code Quality
- ✅ All code must be properly formatted (`dart format`)
- ✅ No analyzer warnings or infos allowed
- ✅ All tests must pass
- ✅ Builds must succeed for all platforms

### PR Requirements
- ✅ PR title must follow semantic commit format:
  - `feat:` - New feature
  - `fix:` - Bug fix
  - `docs:` - Documentation changes
  - `style:` - Code style changes
  - `refactor:` - Code refactoring
  - `perf:` - Performance improvements
  - `test:` - Test additions/changes
  - `build:` - Build system changes
  - `ci:` - CI/CD changes
  - `chore:` - Other changes
  - `revert:` - Revert previous commit

### Security
- ✅ No hardcoded secrets
- ✅ Regular dependency audits
- ✅ Automated vulnerability scanning

## 🎯 Best Practices

### For Developers

1. **Before Pushing:**
   ```bash
   # Format code
   dart format .
   
   # Run analyzer
   flutter analyze
   
   # Run tests
   flutter test
   
   # Build locally
   flutter build apk --debug
   ```

2. **PR Guidelines:**
   - Keep PRs small and focused
   - Write descriptive PR titles
   - Add tests for new features
   - Update documentation

3. **Commit Messages:**
   - Use semantic commit format
   - Be descriptive but concise
   - Reference issues when applicable

### For Releases

1. **Creating a Release:**
   ```bash
   # Tag the release
   git tag -a v1.0.0 -m "Release version 1.0.0"
   
   # Push the tag
   git push origin v1.0.0
   ```

2. **Release Checklist:**
   - [ ] All tests passing
   - [ ] Version updated in `pubspec.yaml`
   - [ ] CHANGELOG updated
   - [ ] Documentation updated
   - [ ] Release notes prepared

## 📈 Monitoring

### Viewing Workflow Results

1. **GitHub Actions:**
   - Go to repository → Actions tab
   - View workflow runs and logs
   - Download artifacts

2. **Discord Notifications:**
   - Receive real-time updates in Discord
   - Click links to view detailed logs
   - Monitor build status at a glance

### Artifacts

The following artifacts are generated:

- **Analysis Report** - Static analysis results (30 days)
- **Coverage Report** - Test coverage HTML report (30 days)
- **Android APK** - Debug/Release APK (7-90 days)
- **Android AAB** - App Bundle for Play Store (90 days)
- **Web Build** - Web application build (7 days)

## 🔍 Troubleshooting

### Common Issues

1. **Build Failures:**
   - Check Flutter version compatibility
   - Verify all dependencies are up to date
   - Review build logs for specific errors

2. **Test Failures:**
   - Run tests locally first
   - Check for environment-specific issues
   - Review test logs

3. **Discord Notifications Not Working:**
   - Verify webhook URL is correct
   - Check webhook permissions in Discord
   - Ensure secret is properly set in GitHub

### Getting Help

- Check workflow logs in GitHub Actions
- Review error messages in Discord notifications
- Consult Flutter documentation
- Open an issue in the repository

## 🔄 Updating Workflows

To modify workflows:

1. Edit files in `.github/workflows/`
2. Test changes on a feature branch
3. Create PR with workflow changes
4. Verify workflows run correctly
5. Merge to main

## 📝 Notes

- **Flutter Version:** The workflows use Flutter 3.24.0 (stable channel)
- **Java Version:** Java 17 for Android builds
- **Timeout:** Jobs have timeouts to prevent hanging builds
- **Caching:** Dependencies and build caches are enabled for faster builds
- **Parallel Execution:** Independent jobs run in parallel for efficiency

## 🎉 Benefits

✅ **Automated Quality Checks** - Catch issues before they reach production
✅ **Consistent Builds** - Same environment every time
✅ **Fast Feedback** - Know immediately if something breaks
✅ **Release Automation** - One-click releases
✅ **Team Visibility** - Everyone sees build status in Discord
✅ **Artifact Management** - Easy access to builds
✅ **Security** - Automated vulnerability scanning
✅ **Documentation** - Coverage and analysis reports

---

**Last Updated:** 2025-12-14
**Maintained By:** Smart Attendance Team
