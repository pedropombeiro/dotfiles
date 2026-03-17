# Epic Comments (Notes)

**⚠️ The REST `/groups/<id>/epics/<iid>/notes` endpoint returns 404 — it does not exist.**

Epics are internally implemented as work items. Comments require GraphQL or the wrapper scripts.

## Quick start — use the scripts

```bash
# Read comments (handles pagination automatically)
epic-notes.sh <group-path> <epic-iid>
# Example:
epic-notes.sh gitlab-org 16428

# Post a comment
create-epic-note.sh <group-id> <epic-iid> "comment body"
# Example:
create-epic-note.sh 9970 16428 "This is my comment"
```

Scripts live in `scripts/` alongside the skill. See the script source for the full GraphQL used.

## Reading comments — GraphQL

```bash
# iid MUST be a quoted string: "16428" not 16428 (integer → type error)
# first: 100 fetches all discussions for most epics in one shot
glab api graphql -f query='
{
  group(fullPath: "gitlab-org") {
    workItem(iid: "16428") {
      widgets {
        type
        ... on WorkItemWidgetNotes {
          discussions(first: 100) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              notes {
                nodes {
                  id
                  body
                  author { username }
                  createdAt
                }
              }
            }
          }
        }
      }
    }
  }
}'
```

Response structure:
- `widgets[].type == "NOTES"` → contains `discussions`
- Each `discussion` is a thread; `notes.nodes` is the list of replies in that thread
- `pageInfo.hasNextPage` + `pageInfo.endCursor` drive pagination

## Pagination

If `pageInfo.hasNextPage` is `true`, fetch the next page with the cursor:

```bash
CURSOR="<endCursor value>"
glab api graphql -f query='
{
  group(fullPath: "<group-path>") {
    workItem(iid: "<epic_iid>") {
      widgets {
        type
        ... on WorkItemWidgetNotes {
          discussions(first: 100, after: "'"$CURSOR"'") {
            pageInfo { hasNextPage endCursor }
            nodes {
              notes {
                nodes { id body author { username } createdAt }
              }
            }
          }
        }
      }
    }
  }
}'
```

In practice: most epics fit in `first: 100`. Only very high-traffic epics need multiple pages.

## Posting a comment — GraphQL mutation

The REST notes endpoint (POST) also returns 404. Use the `createNote` GraphQL mutation:

```bash
# Step 1: get the epic's internal id (not iid)
EPIC_ID=$(glab api "groups/<group_id>/epics/<epic_iid>" | jq '.id')

# Step 2: post the note
glab api graphql -f query="
mutation {
  createNote(input: {
    noteableId: \"gid://gitlab/Epic/${EPIC_ID}\"
    body: \"Your comment here\"
  }) {
    note { id body }
    errors
  }
}"
```

The `noteableId` format is always `gid://gitlab/Epic/<internal_id>` — using the internal `id`, not the `iid`.

## Template files

The `.graphql` files in `assets/graphql/` contain the same queries as above, with `$GROUP_PATH`, `$EPIC_IID`, `$EPIC_GLOBAL_ID`, and `$BODY` placeholders for scripted substitution:

- `assets/graphql/epic-notes.graphql` — read query with pagination fields
- `assets/graphql/create-note.graphql` — `createNote` mutation

## Why REST doesn't work

GitLab migrated epics to the work items data model. The legacy REST endpoints for epic notes (`/notes`, `/discussions`) were removed. The epic response still includes a `work_item_id` field that exposes this relationship. GraphQL via `group.workItem(iid: "...")` is the stable path.
