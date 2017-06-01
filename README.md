# bigfix-sync

This is currently only an idea / concept.

## Idea / Concept

- 2 way sync bigfix site content
- mapping of 1 (git) folder to 1 custom site
  - git pull before sync
  - git add/commit/push after sync
- Import content from (git) folder to a single site in a Root Server
  - If content exists in server that has never synced and has a name conflict, check mod times, do other conflict resolution
  - Since the (git) folder should be version controlled, then it makes sense to favor the server content when overwriting
- Export content from a single site in a Root Server to a (git) folder
  - Assign GUIDs & sync time to xml metadata to both the exported content and update the content in the root with the same