# Automated pull request releases

Every merged pull request publishes one GitHub Release from the merge commit.
The release tag is `release-pr-<number>`, so rerunning a workflow cannot create a
second release for the same pull request.

The release notes include the pull request description, individual commit
subjects, a file-by-file change summary, labels, authorship, and links back to
the pull request and complete diff. If a pull request has no description, its
commit subjects become the primary summary instead; the notes therefore never
degrade to only a pull request number and title.

The event-facing workflow is `release-on-merge.yml`. It calls the reusable
`publish-release.yml` workflow only after GitHub confirms that the pull request
was merged. The reusable workflow may also be called by another workflow when
it supplies a pull request number and merge commit SHA.
