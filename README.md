# bigfix-sync

This is currently only an idea / concept.

## Idea / Concept

- 2 way sync bigfix site content
- mapping of 1 git repo/folder to 1 custom site
  - git pull before sync
  - git add/commit/push after sync
  - it might be possible to use something other than git for the sync mechanism, but something providing version control makes sense.
- Import content from (git) folder to a single site in a Root Server
  - If content exists in server that has never synced and has a name conflict, check mod times, do other conflict resolution
  - Since the (git) folder should be version controlled, then it makes sense to favor the server content when overwriting
- Export content from a single site in a Root Server to a (git) folder
  - Assign GUIDs & sync time to xml metadata to both the exported content and update the content in the root with the same


## Questions

- Can the `fixlet modification time` and `sync time` and `GUID` all be the same but the content different?
- How to handle conflict resolution when 1 item does not yet have a `GUID` assigned, but have the same `fixlet modification time` but different content?
  - the `fixlet modification time` is only updated by the console, may not be affected if content is exported, edited, then imported. 
- Does the bigfix content have an import time?  (check rest api)
