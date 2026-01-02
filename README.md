# POM Version Updater

Bash script to automate updating Maven dependency version ranges to fixed versions across multiple WIoTP repositories.

## 📋 Prerequisites

Before running the script, make sure you have:

- **Python 3** - For XML parsing
- **Git** - Configured with your credentials
- **GitHub CLI (gh)** - For creating pull requests
  - Install: `brew install gh` (macOS) or see https://cli.github.com/
  - Authenticate: `gh auth login`

## 🚀 Quick Start

### 1. Setup

```bash
cd pom-updater
chmod +x update-pom-versions.sh
```

### 2. Add Repository Names

Edit `repos.txt` and add your repository names (one per line):

```
wiotp-repo-1
wiotp-repo-2
wiotp-repo-3
```

### 3. Run the Script

```bash
./update-pom-versions.sh
```

## 📖 How It Works

The script will:

1. **Prompt for Configuration**
   - Organization name (default: wiotp)
   - Folder for cloned repos (default: temp_repos)
   - Branch name (default: feature/update-pom-versions)
   - Jira issue number

2. **For Each Repository:**
   - Clone the repository
   - Scan all `pom.xml` files for version ranges
   - Display found ranges in a table
   - Ask you to specify fixed version for each dependency
   - Update the `pom.xml` files
   - Create a feature branch
   - Commit and push changes
   - Create a Pull Request

3. **Show Summary**
   - Total repositories processed
   - Success/failure count

## 💡 Example Session

```bash
$ ./update-pom-versions.sh

===============================================================================
                    POM Version Updater - WIoTP Team
===============================================================================

Enter organization name [wiotp]: wiotp
Enter folder name to store cloned repos [temp_repos]: temp_repos
Enter branch name [feature/update-pom-versions]: feature/update-pom-versions
Enter Jira Issue (e.g., WIOTP-1234): WIOTP-5678

Found 3 repository/repositories to process

Do you want to proceed? (y/n): y

===============================================================================
[1/3] Processing: wiotp-example-repo
===============================================================================

--Cloning wiotp-example-repo...--

Scanning for version ranges...

Found version ranges:
================================================================
1. com.ibm.wiotp.util:com.ibm.wiotp.util.httpservice
   Current: [4.0.0, 5.0.0)
   File: /path/to/pom.xml

2. com.ibm.wiotp.core:wiotp-core-api
   Current: [3.1.0, 4.0.0)
   File: /path/to/pom.xml
================================================================

[1] com.ibm.wiotp.util:com.ibm.wiotp.util.httpservice
Current range: [4.0.0, 5.0.0)
Enter fixed version (or 'skip'): 4.2.1
✓ Will update to: 4.2.1

[2] com.ibm.wiotp.core:wiotp-core-api
Current range: [3.1.0, 4.0.0)
Enter fixed version (or 'skip'): 3.5.2
✓ Will update to: 3.5.2

Creating branch: feature/update-pom-versions
Committing changes...
Pushing branch to remote...
Creating pull request...
✓ Pull request created successfully

===============================================================================
                              SUMMARY
===============================================================================
Total repositories: 3
✓ Successful: 3
✗ Failed: 0
===============================================================================
```

## 📁 Project Structure

```
pom-updater/
├── update-pom-versions.sh   # Main script (run this)
├── functions.sh              # Reusable functions
├── repos.txt                 # List of repositories
└── README.md                 # This file
```

## 🔧 Configuration

### Organization and Branch

Edit these values in `functions.sh` if you want different defaults:

```bash
# Default values (can be overridden at runtime)
ORG_NAME="wiotp"
BRANCH_NAME="feature/update-pom-versions"
```

### PR Template

The PR title and body are defined in the `createPR` function in `functions.sh`. Customize as needed.

## 🐛 Troubleshooting

### "gh: command not found"

Install GitHub CLI:
```bash
# macOS
brew install gh

# Linux
# See: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
```

Then authenticate:
```bash
gh auth login
```

### "Python 3 not found"

Install Python 3:
```bash
# macOS
brew install python3

# Linux
sudo apt-get install python3
```

### "Failed to clone repository"

Make sure:
- You have SSH keys configured for github.ibm.com
- You have access to the repository
- Repository name is correct in repos.txt

### "Failed to create pull request"

Make sure:
- GitHub CLI is authenticated: `gh auth status`
- You have permission to create PRs in the repository
- The base branch exists

## 📝 Tips

1. **Start Small**: Test with 2-3 repos first
2. **Use Skip**: Type 'skip' for dependencies you don't want to update
3. **Cleanup**: The script asks if you want to cleanup cloned repos at the end
4. **Batch Processing**: Process repos in batches (10-20 at a time)

## 🔒 Security

- Never commit GitHub tokens to the repository
- Use SSH keys for Git authentication
- Review all PRs before merging

## 📞 Support

For issues:
1. Check the error messages in the terminal
2. Verify prerequisites are installed
3. Check GitHub CLI authentication: `gh auth status`

## 📄 License

Internal IBM tool - for WIoTP team use only.