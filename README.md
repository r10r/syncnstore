# -- syncnstore ( sync'n store ) --

Sync and store your data.


## -- sparse backups --

rsync -avH --compare-dest=$(pwd)/data1.sync1/ data1 data1.sync2


### -- restore --

--compare-dest=DIR
