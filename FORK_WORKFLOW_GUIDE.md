# Fork Workflow Guide for Local Voice AI

This guide explains how to work with your forked Local Voice AI repository effectively.

## Current Setup

Your repository is configured with:
- **origin**: Points to your fork at `https://github.com/matlowai/local-voice-ai.git`
- **upstream**: Points to the original repository at `https://github.com/ShayneP/local-voice-ai.git`

Your `main` branch is now properly configured to track `origin/main`, which means:
- When you're on the main branch, `git push` and `git pull` will automatically use origin
- VS Code's sync button will work correctly with your fork

## Daily Workflow Commands

### 1. Sync with Upstream (Original Repository)
Keep your fork updated with changes from the original repository:

```bash
# Fetch latest changes from upstream
git fetch upstream

# Switch to your main branch (if not already there)
git checkout main

# Merge upstream changes into your local main branch
git merge upstream/main

# Push updated main to your fork
git push origin main
```

### 2. Creating Feature Branches
Always create a new branch for each feature or bug fix:

```bash
# Create and switch to a new feature branch
git checkout -b feature/your-feature-name

# Make your changes...

# Add and commit your changes
git add .
git commit -m "Describe your changes"

# Push the feature branch to your fork
git push origin feature/your-feature-name
```

### 3. Keeping Your Branch Updated
If you're working on a long-lived branch, regularly sync with upstream:

```bash
# On your feature branch
git fetch upstream
git merge upstream/main
```

## Best Practices

### 1. Branch Naming Convention
- Use descriptive names: `feature/audio-improvements`, `bugfix/docker-issue`
- Use kebab-case (lowercase with hyphens)

### 2. Commit Messages
- Use the present tense: "Add feature" not "Added feature"
- Be specific about what changed
- Include why the change was made if it's not obvious

### 3. Regular Syncing
- Sync with upstream before starting new work
- Sync at least weekly if you're actively developing
- Always sync before submitting pull requests

### 4. Working with Multiple Remotes
- **origin**: Your fork - where you push your changes
- **upstream**: Original repository - where you pull updates from

## Advanced Workflow

### 1. Submitting Pull Requests
If you want to contribute back to the original repository:

1. Ensure your branch is up to date with upstream:
   ```bash
   git fetch upstream
   git merge upstream/main
   ```

2. Push your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

3. Go to your fork on GitHub and click "New pull request"

### 2. Handling Merge Conflicts
When syncing with upstream, you might encounter conflicts:

```bash
# Fetch upstream changes
git fetch upstream

# Try to merge
git merge upstream/main

# If conflicts occur:
# 1. Resolve conflicts in your editor
# 2. Mark files as resolved: git add <filename>
# 3. Complete the merge: git commit
# 4. Push to your fork: git push origin main
```

### 3. Rebasing Instead of Merging
For a cleaner history, you can rebase instead of merge:

```bash
# Fetch upstream changes
git fetch upstream

# Rebase your current branch on top of upstream/main
git rebase upstream/main

# If conflicts occur, resolve them and continue:
git rebase --continue

# Force push to your fork (only for your own branches!)
git push --force-with-lease origin feature-branch
```

## Quick Reference Commands

| Task | Command |
|------|---------|
| Sync with upstream | `git fetch upstream && git merge upstream/main` |
| Create new branch | `git checkout -b branch-name` |
| Push to your fork | `git push origin branch-name` |
| Check remotes | `git remote -v` |
| Check branch tracking | `git branch -vv` |
| Check status | `git status` |
| View commit history | `git log --oneline --graph --all` |

## Your Current Status

✅ You have successfully:
- Forked the original repository
- Configured your local repository with origin and upstream remotes
- Fixed branch tracking so main now tracks origin/main
- Updated Python to version 3.12 in Dockerfiles
- Set up proper upstream tracking

Your fork is available at: https://github.com/matlowai/local-voice-ai

## Python Version Updates

The project has been updated to use Python 3.12:
- `agent/Dockerfile`: Uses `python:3.12-slim-bookworm` (with configurable PYTHON_VERSION)
- `whisper/Dockerfile`: Uses `python:3.12-slim-bookworm`

## VS Code Integration

### Sync Button Behavior
- The VS Code sync button now works correctly with your fork
- When on the main branch, clicking "Sync" will pull changes from and push changes to your fork (origin)
- The sync button will NOT pull from upstream - you need to do this manually with the commands above

### Checking Branch Tracking in VS Code
- Open the VS Code terminal and run `git branch -vv` to see which remote each branch tracks
- Your main branch should show `[origin/main]` indicating it properly tracks your fork

## Next Steps

1. Continue developing new features in your fork
2. Regularly sync with upstream to stay updated
3. Consider contributing back to the original project through pull requests

## Troubleshooting

### "Permission denied" when pushing
Ensure you're pushing to `origin` (your fork), not `upstream`:
```bash
git push origin main  # Correct
git push upstream main  # Will fail - you don't have write access
```

### "Branch is ahead by X commits"
This is normal after you've made changes. Push to your fork:
```bash
git push origin main
```

### Lost track of which remote is which
Always check with:
```bash
git remote -v
```
This will show you exactly where each remote points.

### VS Code Sync Button Not Working
If the VS Code sync button isn't working properly:
1. Check that your main branch is tracking the correct remote:
   ```bash
   git branch -vv
   ```
   You should see `[origin/main]` next to your main branch.

2. If it's tracking the wrong remote, fix it with:
   ```bash
   git branch --set-upstream-to=origin/main main
   ```

3. If you're still having issues, you can always use the command line instead:
   ```bash
   git pull origin main
   git push origin main
   ```

### Merge Conflicts When Syncing
If you get conflicts when syncing with upstream:
1. Don't panic - this is normal when both repositories have changes
2. Open the conflicted files in your editor
3. Look for the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
4. Decide which changes to keep (yours, upstream's, or a combination)
5. Remove the conflict markers
6. Run `git add <filename>` for each resolved file
7. Complete with `git commit`
8. Push to your fork: `git push origin main`