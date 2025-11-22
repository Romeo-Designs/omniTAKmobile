# GitLab CI/CD Setup for OmniTAK Mobile

## Quick Setup (5 minutes)

### Step 1: Create GitLab Repository

1. Go to https://gitlab.com (or your GitLab instance)
2. Click **New Project** → **Create blank project**
3. Name: `omnitak-mobile`
4. Visibility: Private (recommended)
5. Click **Create project**

### Step 2: Connect Local Repository

```bash
cd ~/omniTAK-mobile

# Add GitLab remote (replace with your URL)
git remote add gitlab https://gitlab.com/YOUR_USERNAME/omnitak-mobile.git

# Or if already exists, update it
git remote set-url gitlab https://gitlab.com/YOUR_USERNAME/omnitak-mobile.git

# Check remotes
git remote -v
```

### Step 3: Push to GitLab

```bash
# Commit any changes
git add .
git commit -m "Setup CI/CD for Android builds"

# Push to GitLab
git push gitlab main

# Or if your branch is named differently
git push gitlab master
```

### Step 4: Watch the Build

1. Go to your GitLab project
2. Click **CI/CD → Pipelines** (left sidebar)
3. You'll see a pipeline running with these stages:
   - ⚙️ **setup** - Install Bazel, Rust, Android tools
   - ✓ **validate** - Check project structure
   - 🔧 **build_native** - Compile Rust libraries
   - 📦 **build_app** - Build Android APK
   - (Optional) **test**, **package**

4. Click on the pipeline to see detailed logs

### Step 5: Download the APK

Once the pipeline completes (✓ green checkmark):

1. Click on the **build_android_apk** job
2. On the right side, click **Browse** under "Job artifacts"
3. Navigate to `build-outputs/omnitak-debug.apk`
4. Click to download

Or use the download button at the top of the pipeline page.

## Pipeline Stages

The `.gitlab-ci.yml` already configured with:

### 1. Setup Environment
- Installs Bazel 7.2.1
- Installs Rust with Android targets
- Downloads Android SDK/NDK

### 2. Validate Project
- Checks BUILD.bazel files
- Verifies project structure
- Validates configuration

### 3. Build Rust Native Libraries
- Builds for arm64-v8a, armeabi-v7a, x86_64, x86
- Caches libraries for faster subsequent builds
- Stores as artifacts

### 4. Build Android APK
- Uses Bazel to build APK
- Creates debug and release APKs
- Stores APKs as artifacts (1 week retention)

## Customization

### Change APK Name

Edit `.gitlab-ci.yml` line 229:
```yaml
- cp bazel-bin/apps/omnitak_android/omnitak_android.apk build-outputs/omnitak-v1.0.0.apk
```

### Build Only on Tags

To build only when you create a release tag:

```yaml
# In .gitlab-ci.yml, change:
only:
  - branches
  - tags

# To:
only:
  - tags
```

Then trigger builds with:
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push gitlab v1.0.0
```

### Add Release Signing

For production releases, add signing configuration:

1. **Generate keystore**:
   ```bash
   keytool -genkey -v -keystore release.keystore -alias omnitak -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **Add to GitLab CI/CD Variables**:
   - Go to **Settings → CI/CD → Variables**
   - Add:
     - `KEYSTORE_FILE` (File type): Upload `release.keystore`
     - `KEYSTORE_PASSWORD` (Protected, Masked)
     - `KEY_ALIAS`: omnitak
     - `KEY_PASSWORD` (Protected, Masked)

3. **Update `.gitlab-ci.yml`**:
   ```yaml
   build_android_release:
     script:
       - bazel build -c opt //apps/omnitak_android
       - jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
         -keystore $KEYSTORE_FILE \
         -storepass $KEYSTORE_PASSWORD \
         -keypass $KEY_PASSWORD \
         bazel-bin/apps/omnitak_android/omnitak_android.apk \
         $KEY_ALIAS
   ```

## Monitoring Builds

### Email Notifications

GitLab sends emails by default when:
- ✓ Pipeline succeeds (first successful after failures)
- ✗ Pipeline fails

Configure in: **Settings → Notifications**

### Slack/Discord Notifications

1. Go to **Settings → Integrations**
2. Choose Slack or Discord
3. Add webhook URL
4. Select events: Pipeline events

### Build Status Badge

Add to README.md:
```markdown
[![Pipeline Status](https://gitlab.com/YOUR_USERNAME/omnitak-mobile/badges/main/pipeline.svg)](https://gitlab.com/YOUR_USERNAME/omnitak-mobile/-/pipelines)
```

## Troubleshooting

### "No runners available"

**For GitLab.com** (shared runners):
- Go to **Settings → CI/CD → Runners**
- Enable "Enable shared runners for this project"

**For self-hosted GitLab**:
- You need to setup a GitLab Runner (see BUILD_ANDROID.md)

### "Build timeout"

Default timeout is 1 hour. First builds take ~25 minutes.

To increase:
- **Settings → CI/CD → General pipelines**
- Change **Timeout** to 2 hours

### "Rust libraries not found"

The pipeline caches Rust libraries between builds. If cache is corrupted:

1. Go to **CI/CD → Pipelines**
2. Click **Clear runner caches**
3. Re-run pipeline

### "Bazel build failed"

Check the job logs for specific errors:
1. Click on the failed job
2. Scroll through the logs
3. Look for "ERROR:" lines

Common issues:
- Missing native libraries → Check build_rust_libraries stage
- Bazel syntax errors → Validate BUILD.bazel files locally
- Platform mismatch → (This shouldn't happen on Linux CI)

## Performance Tips

### Faster Builds

1. **Cache everything**:
   The `.gitlab-ci.yml` already caches:
   - Bazel cache (`.bazel-cache/`)
   - Gradle cache (`.gradle/`)
   - Rust libraries (`modules/omnitak_mobile/android/native/lib/`)

2. **Use specific runners**:
   - Tag runners with `android` tag
   - Assign to specific jobs for faster scheduling

3. **Build only what changed**:
   ```yaml
   build_android_apk:
     only:
       changes:
         - apps/omnitak_android/**/*
         - modules/omnitak_mobile/**/*
         - crates/**/*
   ```

### Cost Optimization (CI/CD Minutes)

**GitLab.com**:
- Free tier: 400 CI/CD minutes/month
- Android build: ~25 minutes
- You can do ~16 builds/month on free tier

**Self-hosted Runner**:
- Unlimited minutes
- Run on your own hardware
- See BUILD_ANDROID.md for setup

## Quick Commands

```bash
# Push and trigger build
git push gitlab main

# Push tag for release build
git tag -a v1.0.0 -m "Release 1.0.0"
git push gitlab v1.0.0

# Check pipeline status
git push gitlab main && echo "Check: https://gitlab.com/YOUR_USERNAME/omnitak-mobile/-/pipelines"

# Download latest APK (using GitLab CLI)
glab ci artifact download
```

## Next Steps

1. ✅ Push code to GitLab
2. ✅ Watch first build complete (~25 min)
3. ✅ Download APK
4. ✅ Test on Android device/emulator
5. Configure signing for production releases
6. Set up automatic deployments to Google Play (optional)

## Support

- **GitLab CI/CD Docs**: https://docs.gitlab.com/ee/ci/
- **Bazel Docs**: https://bazel.build/
- **Pipeline Issues**: Check job logs in GitLab UI
