# -- syncnstore ( sync'n store ) --

Sync and store your data.


## -- sparse backups --


rsync -avH data1 data1.sync1
rsync -avH --compare-dest=$(pwd)/data1.sync1 data1 data1.sync2


### -- restore --

--compare-dest=DIR


## -- rsync --

### -- EXIT VALUES --

* mind rsync exit values
* distinguish between temporary, minor and severe errors
