# Development/Deploying workflow

## Development workflow

1. Open a PR with changes
2. Run `npx changeset` to generate a new changeset
3. If changes are approved and merged, a github action will open a PR "Version Packages" and create a corresponding branch `changeset-release/changeset`
4. If a deployment of the contracts should to be done that would affect the deployed contract addresses, checkout the branch `changeset-release/changeset`,
*follow the deployment steps below,* commit changes, and push that branch, which will contain the updated deployed addresses.
5. Merge the PR "Version Packages" to master, which will trigger a github action to publish the new packages to npm.
