### Processes

#### Export

When an Export is run, the tool enumerates through all of the Fixlets in the configured sites. If the Fixlet has a GUID attached as a MIMEField, the fixlet will be exported as-is. If the Fixlet does not, a PUT will be performed against the Fixlet and a GUID will be assigned to a MIMEField. The Fixlet will then be exported.

Fixlets that have not been modified in BigFix since last sync run will not be exported.

#### Import

When an Import is run, the tool enumerates through all of the Fixlets in the configured sites as well as all of the Fixlets in the configured disk-based repository. Any Fixlets that have been modified on disk since last run will be updated in the custom site. Any Fixlets that exist in the site and have a GUID but are not on the disk-based repository will be backed up and removed.

Fixlets that have not been modified on disk since last sync will not be imported.

#### Sync

A sync involves an Export followed by an Import.