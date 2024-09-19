# finalcut-git
So, PostLab used to be great.  But then they released PostLab 2 with the intention of letting you "bring your own storage".  
Except, for our use case, this super duper sucks because we only used postlab to sync project files and don't want to fuck around with finding a different storage provider.  Also, I'm not interested in paying $200/licence for each of my users up front in my poor season.
And then, today, September 17, postlab shat the bed and now I can't even check in on v1 – the check for changes button makes that little ping noise and nothin' works.  Sooooo we're doing this now.  

## Contents
- **gitignore-template**: .gitignore to avoid syncing render files, or aliases to original media.  The big benefit of this is that it will prevent relinking if users aren't working off a central file server.

## Todo
- [ ] Checkout / Locking mechanism
- [ ] Script to check for and create a GIT private key for the end-user to report back to manager