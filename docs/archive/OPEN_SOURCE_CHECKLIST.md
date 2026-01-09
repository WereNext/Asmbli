# Open Source Preparation Checklist for Asmbli

## 🔐 1. Security & Sensitive Information Cleanup

### Immediate Actions Required:

#### API Keys & Credentials
- [ ] Remove all hardcoded API keys, tokens, and credentials
- [ ] Create `.env.example` files with placeholder values
- [ ] Add `.env` to `.gitignore` (if not already)
- [ ] Audit all configuration files for sensitive data

#### Files to Review/Clean:
```bash
# Check these locations:
- All .env files (ensure they're in .gitignore)
- apps/desktop/lib/core/config/
- Any OAuth configuration files
- Database connection strings
- Service account files
```

#### Secrets Found to Address:
- No actual API keys found (only test keys like 'sk-test123')
- GitHub organization references at:
  - netlify/functions/migrate.ts
  - netlify/functions/db-test.ts
  - apps/api/functions/migrate.ts
  - apps/api/functions/db-test.ts

### Git History Cleanup
```bash
# If you have committed secrets in the past:
# Use BFG Repo-Cleaner or git filter-branch
# Example with BFG:
java -jar bfg.jar --delete-files "*.env" --no-blob-protection
git push --force
```

## 📄 2. Legal & Licensing

### Required Files:

#### LICENSE
```markdown
# Choose appropriate license:
- MIT (most permissive)
- Apache 2.0 (patent protection)
- GPL v3 (copyleft)
- Business Source License (delayed open source)
```

#### COPYRIGHT
- Add copyright headers to all source files
- Update copyright notices in Runner.rc and other platform files

#### NOTICE (if using Apache 2.0)
- Attribution for third-party components
- List of dependencies and their licenses

## 📚 3. Documentation

### Essential Documentation:

#### README.md Updates
- [ ] Clear project description and value proposition
- [ ] Installation instructions for all platforms
- [ ] Quick start guide
- [ ] Feature overview with screenshots
- [ ] System requirements
- [ ] Build instructions from source
- [ ] Configuration guide
- [ ] Troubleshooting section
- [ ] Links to additional resources

#### CONTRIBUTING.md
```markdown
# Should include:
- Code of Conduct reference
- Development setup
- Code style guidelines
- Pull request process
- Testing requirements
- Commit message format
- Issue reporting guidelines
```

#### CODE_OF_CONDUCT.md
- Use Contributor Covenant or similar
- Contact information for reporting issues

#### SECURITY.md
```markdown
# Should include:
- Security policy
- How to report vulnerabilities
- Supported versions
- Security update process
```

## 🛠️ 4. Development Setup

### Configuration Templates:

#### Create example configuration files:
```bash
# Create these files:
.env.example
apps/desktop/.env.example
apps/web/.env.example

# With content like:
ANTHROPIC_API_KEY=your_api_key_here
OPENAI_API_KEY=your_api_key_here
DATABASE_URL=sqlite:///./data/asmbli.db
```

#### Docker Support (optional but recommended):
```dockerfile
# Create Dockerfile for easy setup
# Create docker-compose.yml for full stack
```

## 🔄 5. CI/CD & Automation

### GitHub Actions Workflows:

#### .github/workflows/ci.yml
```yaml
# Continuous Integration:
- Build verification (all platforms)
- Test execution
- Lint checks
- Security scanning
```

#### .github/workflows/release.yml
```yaml
# Release automation:
- Version tagging
- Binary building
- Release notes generation
- Asset uploading
```

### Issue & PR Templates:

#### .github/ISSUE_TEMPLATE/
- bug_report.md
- feature_request.md
- documentation.md

#### .github/pull_request_template.md
- Checklist for contributors
- Testing requirements
- Documentation updates

## 🧹 6. Code Cleanup

### Repository Organization:

#### Remove/Archive:
- [ ] Build artifacts (clean build/, dist/ folders)
- [ ] Personal configuration files
- [ ] IDE-specific files (add to .gitignore)
- [ ] Unused dependencies
- [ ] Dead code
- [ ] Internal documentation not relevant to OSS

#### Standardize:
- [ ] Code formatting (run formatters)
- [ ] Import organization
- [ ] Comment cleanup (remove TODOs with internal references)
- [ ] Consistent naming conventions

## 📦 7. Dependencies & Licensing

### Dependency Audit:

#### Check all dependencies for:
- [ ] License compatibility
- [ ] Security vulnerabilities
- [ ] Outdated packages
- [ ] Internal/private packages that need replacement

#### Create dependency documentation:
```bash
# Flutter/Dart
flutter pub deps --no-dev --executables

# Node.js
npm list --depth=0 --prod
```

## 🌍 8. Community Setup

### GitHub Repository Settings:

#### Enable:
- [ ] Issues
- [ ] Discussions
- [ ] Wiki (optional)
- [ ] Projects (for roadmap)
- [ ] Security advisories

#### Configure:
- [ ] Branch protection rules
- [ ] Required reviews
- [ ] CI status checks
- [ ] Semantic versioning tags

### Community Files:

#### FUNDING.yml
```yaml
# Funding options:
github: [username]
patreon: username
custom: ["https://example.com/donate"]
```

#### CODEOWNERS
```
# Define code ownership for reviews
/apps/desktop/ @desktop-team
/packages/ @core-team
```

## 🚀 9. Launch Preparation

### Pre-Launch Checklist:

#### Code Review:
- [ ] Security audit complete
- [ ] No hardcoded secrets
- [ ] All tests passing
- [ ] Documentation complete

#### Legal Review:
- [ ] License chosen and applied
- [ ] Copyright notices added
- [ ] Contributor agreement ready (if needed)
- [ ] Trademark considerations addressed

#### Community Prep:
- [ ] Discord/Slack server created
- [ ] Initial maintainer team identified
- [ ] Governance model decided
- [ ] Roadmap published

## 🎯 10. Specific Actions for Asmbli

### Immediate TODOs:

1. **Clean Sensitive Data:**
   ```bash
   # Update GitHub org references
   sed -i 's/WereNext/your-org/g' netlify/functions/*.ts
   sed -i 's/WereNext/your-org/g' apps/api/functions/*.ts
   ```

2. **Add License:**
   ```bash
   # Add MIT License (example)
   curl -o LICENSE https://raw.githubusercontent.com/github/choosealicense.com/gh-pages/_licenses/mit.txt
   # Update [year] and [fullname] in LICENSE
   ```

3. **Create .env.example:**
   ```bash
   # Copy and sanitize existing .env files
   cp .env .env.example
   # Edit to remove actual values
   ```

4. **Update README:**
   - Remove internal references
   - Add badges (build status, license, version)
   - Include screenshots
   - Add contributor section

5. **Set up CI/CD:**
   - GitHub Actions for Flutter builds
   - Automated testing on PR
   - Release automation

### Repository Structure Recommendations:

```
Asmbli/
├── .github/
│   ├── workflows/
│   ├── ISSUE_TEMPLATE/
│   └── pull_request_template.md
├── apps/
│   ├── desktop/
│   └── web/
├── packages/
├── docs/
│   ├── API.md
│   ├── ARCHITECTURE.md
│   └── DEPLOYMENT.md
├── examples/
│   └── example_configs/
├── LICENSE
├── README.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
└── .env.example
```

## ⚠️ Important Warnings

1. **Never force push to main after going public**
2. **Once open-sourced, assume all code is permanent**
3. **Review all commit history before making public**
4. **Consider squashing commits if history contains sensitive data**
5. **Set up branch protection before announcing**

## 📊 Success Metrics

Track these after open-sourcing:
- Stars/Forks/Watches
- Issue engagement
- PR contributions
- Documentation feedback
- Community growth
- Security reports handled

---

## Next Steps

1. Work through this checklist systematically
2. Get legal review if needed
3. Test the setup with a private group first
4. Soft launch to get initial feedback
5. Public announcement when ready

Remember: It's easier to start restrictive and open up than vice versa. Consider starting with a more restrictive license and clear CLA if you might want commercial options later.