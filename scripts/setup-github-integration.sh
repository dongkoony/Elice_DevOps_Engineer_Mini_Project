#!/bin/bash

# GitHub Integration Setup Script
# Usage: ./setup-github-integration.sh <GITHUB_TOKEN> <REPO_OWNER> <REPO_NAME>

set -e

GITHUB_TOKEN=${1:-$GITHUB_TOKEN}
REPO_OWNER=${2:-"elice-devops"}
REPO_NAME=${3:-"microservices-platform"}

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GitHub token required"
    echo "Usage: $0 <GITHUB_TOKEN> [REPO_OWNER] [REPO_NAME]"
    exit 1
fi

API_BASE="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME"

echo "🔧 Setting up GitHub integration for $REPO_OWNER/$REPO_NAME"

# 1. Enable branch protection for main
echo "📋 Setting up branch protection..."
curl -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "$API_BASE/branches/main/protection" \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "build-and-test",
        "security-scan",
        "continuous-integration/jenkins/pr-merge"
      ]
    },
    "enforce_admins": false,
    "required_pull_request_reviews": {
      "required_approving_review_count": 2,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true,
      "require_last_push_approval": true
    },
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false
  }'

# 2. Create webhook for Jenkins integration
echo "🔗 Creating Jenkins webhook..."
WEBHOOK_URL="http://jenkins.elice-devops.local:8080/github-webhook/"
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "$API_BASE/hooks" \
  -d "{
    \"name\": \"web\",
    \"active\": true,
    \"events\": [
      \"push\",
      \"pull_request\",
      \"release\"
    ],
    \"config\": {
      \"url\": \"$WEBHOOK_URL\",
      \"content_type\": \"json\",
      \"insecure_ssl\": \"0\"
    }
  }"

# 3. Set up repository secrets
echo "🔐 Setting up repository secrets..."
secrets=(
    "JENKINS_API_TOKEN"
    "DOCKER_REGISTRY_PASSWORD"
    "KUBECONFIG"
    "SLACK_WEBHOOK_URL"
    "CODECOV_TOKEN"
)

for secret in "${secrets[@]}"; do
    if [[ -n "${!secret}" ]]; then
        echo "Setting secret: $secret"
        # Note: GitHub CLI or manual setup required for secrets
        gh secret set "$secret" --body "${!secret}" --repo "$REPO_OWNER/$REPO_NAME"
    else
        echo "⚠️  Warning: $secret not set in environment"
    fi
done

# 4. Create CODEOWNERS file
echo "👥 Creating CODEOWNERS file..."
cat > .github/CODEOWNERS << EOF
# Global owners
* @elice-devops/platform-team

# Infrastructure
/aws/terraform/ @elice-devops/infrastructure-team
/aws/kubernetes/ @elice-devops/infrastructure-team

# Microservices
/aws/microservices/ @elice-devops/backend-team

# CI/CD
/.github/ @elice-devops/platform-team
/jenkins/ @elice-devops/platform-team
/Jenkinsfile @elice-devops/platform-team
EOF

# 5. Create pull request template
echo "📝 Creating PR template..."
mkdir -p .github/pull_request_template
cat > .github/pull_request_template/default.md << EOF
## Summary
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Infrastructure change

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Security scan passed

## Deployment
- [ ] Database migrations included
- [ ] Environment variables updated
- [ ] Documentation updated
- [ ] Monitoring/alerting configured

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Tests added/updated
- [ ] Documentation updated

## Screenshots/Logs
<!-- Add any relevant screenshots or log outputs -->
EOF

# 6. Set up issue templates
echo "🎫 Creating issue templates..."
mkdir -p .github/ISSUE_TEMPLATE
cat > .github/ISSUE_TEMPLATE/bug_report.yml << EOF
name: Bug Report
description: File a bug report
title: "[BUG] "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  - type: input
    id: service
    attributes:
      label: Affected Service
      description: Which microservice is affected?
      placeholder: e.g., api-gateway, auth-service
    validations:
      required: true
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Describe the bug
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: What should have happened?
    validations:
      required: true
  - type: textarea
    id: reproduce
    attributes:
      label: Steps to Reproduce
      description: How can we reproduce this?
      placeholder: |
        1. Go to...
        2. Click on...
        3. See error
    validations:
      required: true
EOF

echo "✅ GitHub integration setup complete!"
echo ""
echo "Next steps:"
echo "1. Review and commit the generated files"
echo "2. Push changes to trigger the first pipeline run"
echo "3. Verify webhooks are working in Jenkins"
echo "4. Test pull request workflow"