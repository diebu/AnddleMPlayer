# Repository workflow

- After completing and verifying a change to application source, resources,
  tests, Xcode project settings, or plists, automatically commit the change.
- Prefer `./Scripts/commit-changes.sh "<type: summary>"`. The script stages all
  non-ignored changes, installs the repository hook configuration, and commits.
- The `pre-commit` hook increments the patch version and build number once per
  application-code commit. Do not increment them a second time in the same
  change.
- For a feature or major release, run `./Scripts/bump-version.sh minor` or
  `./Scripts/bump-version.sh major` before committing. The hook detects the
  explicit version change and leaves it unchanged.
- Documentation-only, script-only, and Git-workflow changes should also be
  committed, but they do not change the application version.
- Do not commit generated `build/`, DerivedData, caches, or signing credentials.
- Do not push unless the user explicitly requests it.
- If the execution environment prevents writes to `.git`, verify the change and
  report the exact `./Scripts/commit-changes.sh "<message>"` command that the
  user must run in Terminal.
