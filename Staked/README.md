# CLI Scripts for testing Staked cross-chain operation. See https://staked.cc/

`./lazy/*` - small fragments of simple tasks

`checkSync.sh` - queries Komodo and all Staked chain daemons to see if they're fully sync'd. Can be used to delay further commands that need sync'd chains.

`staked-cli` - skin for komodo-cli calls to all Staked chains. Useful if simlinked to /usr/local/bin/

`getAddresses.sh [integer]` - returns a subset of x addresses from all staked chains (defaults to 5). If less than number of requested addresses exist, they are generated automatically, with keys stored in a json owner read only file.

`stats` - borrowed code from #webworker01, converted for use with Staked notary nodes.

## Any scripts still being tested will display a warning and chance to quit before running.

`chicken.sh` - chaotic migrations with no real purpose. Generates a buttload of addresses and tries to put coins in them. In testing.

`eqMi_*` - scripts for spreading funds evenly across all chains. A few different versions yet to be trimmed and dressed. In testing.
