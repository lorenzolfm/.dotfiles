# Posting

Write every body to a file in the scratchpad first. Then backticks, `$` and newlines reach GitHub intact.

## Anchor inline comments

```bash
gh pr view N -R OWNER/REPO --json headRefOid -q .headRefOid
gh pr diff N -R OWNER/REPO
```

`line` is the line number in the file at the head commit, on `side: "RIGHT"`. To comment on a removed line, use `side: "LEFT"` with the old line number. The line must fall inside a diff hunk. If it doesn't, the API answers 422 `Line could not be resolved`. Move that comment to the nearest changed line or into a conversation comment.

## One review with all inline comments

`review.json`:

```json
{
  "commit_id": "<head sha>",
  "event": "COMMENT",
  "body": "some comments",
  "comments": [
    {"path": "src/features/foo.rs", "line": 42, "side": "RIGHT", "body": "first?"},
    {"path": "src/features/foo.rs", "start_line": 50, "line": 53, "side": "RIGHT",
     "body": "```suggestion\n        .context(\"fetch foo\")?;\n```"}
  ]
}
```

```bash
gh api repos/OWNER/REPO/pulls/N/reviews --method POST --input review.json --jq .html_url
```

- `event` is `COMMENT`, `REQUEST_CHANGES` or `APPROVE`. COMMENT and REQUEST_CHANGES need a body, so keep it to a short line. If you omit `event`, the review stays pending for Lorenzo to submit from the UI.
- A suggestion replaces lines `start_line..line` with its contents, so keep the file's indentation.

## Approve or ACK

```bash
gh pr review N -R OWNER/REPO --approve

sha=$(gh pr view N -R OWNER/REPO --json headRefOid -q .headRefOid)
gh pr review N -R OWNER/REPO --comment --body "ACK $sha"
```

## Reply in a review thread

```bash
gh api --paginate repos/OWNER/REPO/pulls/N/comments \
  --jq '.[] | {id, path, line, user: .user.login, in_reply_to_id, body: .body[:80]}'
gh api repos/OWNER/REPO/pulls/N/comments/COMMENT_ID/replies --method POST \
  -F body=@reply.md --jq .html_url
```

## Conversation comments and issues

```bash
gh pr comment N -R OWNER/REPO --body-file comment.md
gh issue comment N -R OWNER/REPO --body-file comment.md
gh issue create -R OWNER/REPO --title "[Bug] chain: ..." --body-file issue.md
```

Floresta issue titles follow `[Bug] <area>: <what breaks>` or `[Enhancement] <what>`.

## Linear

Use `mcp__linear-server__save_comment` with the issue id and the body. The voice is the same as on GitHub.
