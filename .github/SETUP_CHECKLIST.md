# Repository Setup Checklist

## Initial Setup

### 1. Enable GitHub Actions
- [x] Template renamed: `nvbluefin` in Containerfile, Justfile, README.md, artifacthub-repo.yml
- [ ] Settings → Actions → General → Enable workflows
- [ ] Set "Read and write permissions"

### 2. First Push
```bash
git add .
git commit -m "feat: initial customization"
git push origin main
```

### 3. Deploy
```bash
sudo bootc switch --transport registry ghcr.io/lbssousa/nvbluefin:stable
sudo systemctl reboot
```

## Optional: Production Features

### Enable Signing (Recommended)
```bash
cosign generate-key-pair
# Add cosign.key to GitHub Secrets as SIGNING_SECRET
# Uncomment signing in .github/workflows/build.yml
```

