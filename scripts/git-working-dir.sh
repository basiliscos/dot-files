#!/bin/bash

FILES=`git ls-tree -r --name-only HEAD .`
MAXLEN=0
IFS=$(echo -en "\n\b")
for f in $FILES; do
    if [ ${#f} -gt $MAXLEN ]; then
        MAXLEN=${#f}
    fi
done
for f in $FILES; do
    str=$(git log -1 --pretty=format:"%aD" $f)
    printf "%-${MAXLEN}s -- %s\n" "$f" "$str"
done
