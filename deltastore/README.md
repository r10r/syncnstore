# syncnstore ( sync'n store )

Concept to sync and store your data.

* small storage size
* incremental/differential backup
* fast backup
* fast restore

## tests/benchmarks

### extended attributes

show attributes for files
<pre>
find . -type f -and -size +100M | xargs xattr -l
</pre>

### small files

Small files (<5k) make up 94% of the number of total files
Time required to compress small files (<10k):

<pre>
bash-3.2# time find / -type f -and -size -10k > /dev/null
real	1m23.957s
user	0m1.725s
sys	    0m44.165s
</pre>

#### tar

generate archive:
<pre>
bash-3.2# time find / -type f -and -size -10k | sed 's/.*/"&"/' |  xargs tar rf /tmp/smallfiles.tar
real	7m43.407s
user	3m34.119s
sys	    2m52.301s
</pre>

archive size:
<pre>
bash-3.2# du -hs /tmp/smallfiles.tar
2,3G	/tmp/smallfiles.tar
</pre>

compress archive:
<pre>
bash-3.2# time gzip /tmp/smallfiles.tar
real	0m51.667s
user	0m50.415s
sys	    0m1.097s
</pre>

compressed size:
<pre>
[ruben@rauscher rdifftest]$ du -hs /tmp/smallfiles.tar.gz
428M	/tmp/smallfiles.tar.gz
</pre>

#### shasum
<pre>
bash-3.2# time find / -type f -and -size -10k | sed 's/.*/"&"/'  | xargs shasum
real	4m17.804s
user	0m48.067s
sys	    1m23.424s
</pre>

### remove empty directories

<pre>
find . -type d -and -empty -delete
</pre>

### rsync

* mind rsync exit values
* distinguish between temporary, minor and severe errors
* `--compare-dest` option allows only 20 references which makes it unusable

initial sync
<pre>
real	6m11.258s
user	0m47.868s
sys	6m7.187s
bash-3.2# time /usr/local/bin/rsync --stats -ax -S -H -X --exclude-from=/Users/ruben/.rsync/excludes --max-size=10K+1 / .
</pre>

tar synced directory
<pre>
real	5m28.498s
user	0m23.520s
sys	1m58.167s
bash-3.2# time tar cf rsynctest.tar rsynctest
</pre>

re-sync
<pre>
real	1m27.315s
user	0m12.622s
sys	1m23.973s
bash-3.2# time /usr/local/bin/rsync --stats -ax -S -H -X --exclude-from=/Users/ruben/.rsync/excludes --max-size=10K+1 --log-file ../rsynctest.log.1 / .
</pre>

### sparse image

sync of all files <10k+1

initial sync
<pre>
bash-3.2# time /usr/local/bin/rsync --stats -ax -S -H -X --exclude-from=/Users/ruben/.rsync/excludes --max-size=10K+1 / /Volumes/Disk\ Image/
real	6m29.415s
user	0m47.629s
sys	    5m46.709s
</pre>

size:
<pre>
bash-3.2# du -hs /Users/ruben/backup.sparseimage
3,6G	/Users/ruben/backup.sparseimage
</pre>

signature generation
<pre>
bash-3.2# time rdiff signature /Users/ruben/backup.sparseimage > /Users/ruben/backup.sparseimage.signature
real	0m12.263s
user	0m8.407s
sys	    0m1.505s
</pre>

sync
<pre>
bash-3.2# time /usr/local/bin/rsync --stats -ax -S -H -X --exclude-from=/Users/ruben/.rsync/excludes --max-size=10K+1 / /Volumes/Disk\ Image/
real	1m57.243s
user	0m16.662s
sys	    1m42.620s
</pre>

sparse delta
<pre>
bash-3.2# time rdiff delta /Users/ruben/backup.sparseimage.signature /Users/ruben/backup.sparseimage > /Users/ruben/backup.sparseimage.delta.1
real	0m20.362s
user	0m15.525s
sys	0m1.780s
</pre>

sparse delta size
<pre>
bash-3.2# du -hs /Users/ruben/backup.sparseimage.delta.1
 20M	/Users/ruben/backup.sparseimage.delta.1
</pre>


### signature generation

<pre>
bash-3.2# generate_signatures.sh /tmp/filelist_gt100k.txt 100k
real	38m36.256s
user	28m19.717s
sys	    7m46.087s
</pre>

* Store files and metadata separately ? (use database?, sqlite ?)


## GIT

- use git-hash-object - Compute object ID and optionally creates a blob from a file to create blobs from files
- http://git-scm.com/book/en/Git-Internals-Git-Objects
- http://smalltalkthoughts.blogspot.de/2010/03/git-tree-objects-how-are-they-stored.html

## TAR

find . -type f -name "*.java" | xargs tar rvf myfile.tar

http://alvinalexander.com/blog/post/linux-unix/using-find-xargs-tar-create-huge-archive-cygwin-linux-unix

## TODO

* hash path and name of file (test)
* compress deltas (test)
* save deltas in git together with metadata (test)
* save extended attributes
* sync small files locally
* build boot image from synced data
* reduce sparse image size for faster restore (folders that change often / rarely)
* keep track which files are stored in which sparse images
* create deltas for sparse deltas

patch, delta and signature generation take the same time (if read/write IO take the same time)
patching is fairly fast and inexpensive apart from the IO

### inteligent paritioning/chunking

- identify file types that change often /rarely
- use LSB and OsX file system structure


## change log

- opensnoop (OSX leopard only)
- http://www.osxbook.com/software/fslogger/
