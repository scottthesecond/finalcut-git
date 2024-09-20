# finalcut-git
Keeps final cut projects in sync across remote editing times.  Includes check-in and check-out (locking) functionality to avoid conflicts.
Prevents relinking files when sending projects back-and-forth.

## Why did I make this
It was September of 2024.  The team was cranking through wedding videos, when suddenly, P\*\*\*l\*b shat the bed.  We couldn't check things in, we were getting conflicts all the time, about half a dozen projects were borked.  Support said no one was available because the team was "recovering" from some conference.  After telling them that we weren't able to work, they connected us with a "product specialist" who started the call, irritated at having been awoken from his *rEcOvErY*, by insulting my business partner to his face and telling him that "some users just need hand-holding" (actual quote).  After being shown the issue, he proceeded to stare at the console, completly stumped, and were unable to fix the issue.

Anyway, after deciding that I hate these people (and didn't want to spend $200/license on the upgrade to V2 which doesn't even do the syncing, the entire reason we had for using that product), I made my own knockoff version with bash scripts on a four-hour plane ride while heading home from a shoot.

And so, fcp.git was born (or as we call it at UnnamedFilms, UNFlab).  Hopefully this will be helpful for someone else, too.

## How it works
This is basically a script that makes GIT a little bit more accessible for the less technically-minded folks on your editing team.

Set up a GIT server to use as your remote.  Then, distribute the fcp-git-user.sh to users (or, use something like Platypus to build it as a native macOS app – optional, but beneficial).  The script will prompt users to enter the GIT server details, and then they can check out a project.  Enter the name of the repo on the git server, and fcp-git will download the project and lock it so other users can't work on it the user checks it back in.   

If you user the included scripts on the GIT server to set up the repos, it will add a .gitignore file which prevents the syncing of linked media aliases, so users will not have to relink when syncing back-and-forth.

## Todo
- [ ] Some sort of loading indicator when GIT is working – check in and check out can take a minute and there's currently no feedback to show it's working.
- [ ] Guides for setting up GIT server.
- [ ] Change CHEKCEDOUT to .checkedout
- [ ] Periodic push?  Automatic checkin after inactivity?
- [ ] Conflict resolution
- [X] Checkout / Locking mechanism
- [X] Script to check for and create a GIT private key for the end-user to report back to manager