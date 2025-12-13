# Quick Setup Guide for CI/CD

This guide will help you get the CI/CD pipeline up and running in 5 minutes.

## 🚀 Quick Start

### Step 1: Set Up Discord Webhook (2 minutes)

1. Open Discord and go to your server
2. Click on Server Settings (gear icon)
3. Go to **Integrations** → **Webhooks**
4. Click **New Webhook**
5. Configure:
   - Name: `Smart Attendance CI/CD`
   - Channel: Select your preferred channel (e.g., `#dev-notifications`)
6. Click **Copy Webhook URL**

### Step 2: Add Webhook to GitHub (1 minute)

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add secret:
   - Name: `DISCORD_WEBHOOK_URL`
   - Value: Paste the webhook URL from Discord
5. Click **Add secret**

### Step 3: Push to GitHub (1 minute)

```bash
# Add all CI/CD files
git add .github/

# Commit
git commit -m "ci: add professional CI/CD pipeline with Discord notifications"

# Push to main or develop branch
git push origin main
```

### Step 4: Verify Setup (1 minute)

1. Go to your repository on GitHub
2. Click on the **Actions** tab
3. You should see the CI pipeline running
4. Check your Discord channel for notifications

## ✅ That's It!

Your CI/CD pipeline is now active! Every push and PR will trigger automated checks.

## 🎯 Next Steps

### Test the Pipeline

Create a test PR to see the full pipeline in action:

```bash
# Create a new branch
git checkout -b test/ci-pipeline

# Make a small change
echo "# CI/CD Test" >> TEST.md

# Commit and push
git add TEST.md
git commit -m "test: verify CI/CD pipeline"
git push origin test/ci-pipeline
```

Then create a PR on GitHub and watch the magic happen! 🎉

### Create Your First Release

When you're ready to create a release:

```bash
# Update version in pubspec.yaml first
# Then tag and push
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

The CD pipeline will automatically:
- Build release APK and AAB
- Create a GitHub release
- Notify Discord

## 📊 What You Get

### On Every Push/PR:
- ✅ Code quality checks
- ✅ Static analysis
- ✅ Unit tests with coverage
- ✅ Multi-platform builds
- ✅ Discord notifications

### On Pull Requests:
- ✅ PR validation
- ✅ Security scanning
- ✅ Auto-labeling
- ✅ Coverage reports
- ✅ Build verification

### On Releases:
- ✅ Production builds
- ✅ GitHub releases
- ✅ Artifact uploads
- ✅ Release notifications

### Weekly:
- ✅ Security scans
- ✅ Dependency audits
- ✅ License compliance checks

## 🔧 Customization

### Change Flutter Version

Edit `.github/workflows/*.yml`:
```yaml
env:
  FLUTTER_VERSION: '3.24.0'  # Change this
```

### Modify Notification Format

Edit the Discord notification steps in workflows to customize the message format.

### Add More Platforms

Add jobs for additional platforms (Linux, macOS, Windows) in `ci.yml`.

## 📚 Documentation

For detailed information, see:
- [Full CI/CD Documentation](.github/CICD.md)
- [PR Template](.github/PULL_REQUEST_TEMPLATE.md)

## 🆘 Troubleshooting

### Discord Notifications Not Working?
- Verify webhook URL is correct
- Check webhook is not disabled in Discord
- Ensure secret name is exactly `DISCORD_WEBHOOK_URL`

### Builds Failing?
- Check Flutter version compatibility
- Run `flutter pub get` locally
- Review error logs in GitHub Actions

### Need Help?
- Check workflow logs in GitHub Actions
- Review error messages in Discord
- Open an issue in the repository

---

**Congratulations! Your professional CI/CD pipeline is ready! 🎉**
