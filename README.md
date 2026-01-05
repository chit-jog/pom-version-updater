# 🔧 POM Version Updater

Automates updating Maven POM dependency version ranges to fixed versions across multiple repositories.

## ✨ What It Does

- 🔍 Scans `pom.xml` files for version ranges (e.g., `[4.0.0, 5.0.0)`)
- ✏️ Prompts you to specify fixed versions
- 📝 Updates all `pom.xml` files
- 🌿 Creates a feature branch
- 💾 Commits and pushes changes
- 🔀 Creates a Pull Request

## 📋 Prerequisites

```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login
```

## 🚀 Setup

1. **Clone this repository**
   ```bash
   git clone <your-repo-url>
   cd pom-version-updater
   ```

2. **Add repository names to `repos.txt`**
   ```
   repo-name-1
   repo-name-2
   repo-name-3
   
   ```
   ⚠️ **Important:** Add a blank line at the end after your last repository name

3. **Make script executable**
   ```bash
   chmod +x update-pom-versions.sh
   ```

## 💻 Usage

```bash
./update-pom-versions.sh
```

### You'll be prompted for:

1. **Organization name** (default: `wiotp`)
2. **Folder name** for cloned repos (default: `temp_repos`)
3. **Branch name** (default: `feature/update-pom-versions`)
4. **Jira Issue** (e.g., `WIOTP-1234`)

### For each repository:

1. Script shows all version ranges found
2. You enter fixed version for each dependency
3. Script updates files, commits, and creates PR

## 📖 Example

```bash
$ ./update-pom-versions.sh

Enter organization name [wiotp]: wiotp
Enter folder name [temp_repos]: temp_repos
Enter branch name [feature/update-pom-versions]: fix/pom-versions
Enter Jira Issue: WIOTP-1234

Found version ranges:
1. com.ibm.wiotp.util:com.ibm.wiotp.util
   Current: [3.0.0, 4.0.0)
   
Enter fixed version (or 'skip'): 3.0.28
✓ Will update to: 3.0.28
```

## 📁 File Structure

```
pom-version-updater/
├── update-pom-versions.sh    # Main script
├── lib/
│   └── functions.sh           # Helper functions
├── repos.txt                  # List of repositories
├── .gitignore                 # Excludes temp files
└── README.md                  # This file
```

## 📝 Notes

- Temporary cloned repositories are stored in the folder you specify
- You can skip any dependency by entering `skip`
- Pull requests are created automatically via GitHub CLI
- The script handles multiple `pom.xml` files in subdirectories

## ⚠️ Troubleshooting


**"No repositories found in repos.txt"**
- Make sure `repos.txt` exists and contains repository names
- Ensure repository names are not commented out (no `#` at start)
- **Add a blank line at the end of the file after your last repository**

