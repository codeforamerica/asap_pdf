# Hardened Image Rollout

Open items and manual steps for rolling out the hardened Rails app image. This
is a working checklist. Remove it, or fold what's still useful into
[deployment.md][deployment], once the rollout is complete.

## What changes

- The Rails app image is built on [Docker Hardened Images][dhi] (`dhi.io`)
  and runs as the `nonroot` user.
- The deploy workflow builds and pushes the Rails app image through the
  shared [`ecr-build-push.yaml`][shared-workflow] workflow (the `build_app`
  job), instead of a `docker build` step in the `deploy` job.
- The Lambda images, the SSM version parameter and `tofu apply` are
  unchanged.

## Before merging to `dev`

These need someone with admin access to the GitHub repo.

- [ ] Add an `AWS_ROLE_ARN` **secret** to the `staging` and `prod`
      environments.
  - Use the same value as the existing `AWS_ROLE_ARN` **variable** in each
    environment.
  - The shared workflow reads the role from `secrets`, not `vars`.
- [ ] Confirm the org secrets `DOCKER_HUB_USERNAME` and
      `DOCKER_HUB_READONLY_TOKEN` are shared with this repo. The shared
      workflow uses them to log in to `dhi.io` and pull the base images.

## Staging rollout

1. [ ] Merge the PR into `dev`.
1. [ ] In the "Deploy to AWS" run, check that:
   - `build_app` pushes the image and its summary shows the image digest.
   - `deploy` finishes, and ECS reaches a steady state.
1. [ ] In staging, check that:
   - `/up` returns 200.
   - Logging in and browsing sites and documents work.
   - CSS and JS load.
1. [ ] ECS Exec sessions now run as `nonroot`. Check that the usual console
      and rake commands still work, for example `bin/rails console` and
      `bin/rails users:create_admin`.
1. [ ] Check the ECR scan of the new image. This needs access to the staging
      AWS account. See [Checking the scan](#checking-the-scan).
1. [ ] Get sign-off from the owning team.

## Production rollout

1. [ ] Merge `dev` into `main` through the usual deploy PR.
1. [ ] Repeat the run and app checks from the staging rollout against prod.
1. [ ] Compare the prod ECR scan with the baseline recorded on SOC-3498.
1. [ ] Report on SOC-3498 any OS-level findings that remain.

## After rollout

- [ ] Remove the `ECR_REPOSITORY_RAILS_APP` variable from the `staging` and
      `prod` environments. Nothing reads it anymore.
- [ ] Record the decision in an ADR under `docs/adr/` and list it in
      [the docs index][docs-index].
- [ ] Update [deployment.md][deployment] to describe the `build_app` job and
      the GitHub settings above.
- [ ] Remove this file.

## Checking the scan

The registry uses Amazon Inspector enhanced scanning.

- The shared workflow pushes a single-platform image with no attestations,
  so the scan can be queried by tag.
- Before this change, the image was pushed as an image index. Querying the
  tag returned `UNSUPPORTED_IMAGE`, and only the amd64 manifest inside the
  index was scanned.

```sh
REPO=asap-pdf-staging-app  # or asap-pdf-prod-app
TAG=<commit sha>

aws ecr describe-image-scan-findings --repository-name "$REPO" \
  --image-id imageTag="$TAG" --query 'imageScanStatus'

aws ecr describe-image-scan-findings --repository-name "$REPO" \
  --image-id imageTag="$TAG" --output json \
  | jq -r '.imageScanFindings.enhancedFindings[].severity' | sort | uniq -c
```

> [!NOTE]
> Count severities from the full findings list, as above. The
> `findingSeverityCounts` summary in the same response appears to cover only
> the first page of findings.

## Open items

| Item                                                                                  | Resolved by                     | Status |
| ------------------------------------------------------------------------------------- | ------------------------------- | ------ |
| Accept OS-level findings that DHI has patched but Debian hasn't, or file an exception | Security / Vanta owner          | Open   |
| Whether Amazon Inspector honors DHI's backported fixes (VEX)                          | First ECR scan of the new image | Open   |
| Whether Aikido flags the DHI base images for being pinned by tag, not digest          | Team                            | Open   |
| Who signs off on staging before promotion                                             | Owning team                     | Open   |
| Remove Thruster (separate PR stacked on this one)                                     | Team                            | Open   |

## Rollback

Revert the merge on `dev` or `main`. The next deploy rebuilds the image from
the previous Dockerfile using the old inline build step.

[deployment]: deployment.md
[dhi]: https://docs.docker.com/dhi/
[docs-index]: README.md
[shared-workflow]: https://github.com/codeforamerica/github-actions/blob/main/.github/workflows/ecr-build-push.yaml
