#! /bin/bash

LIMIT=1 ##Limit in GB



SIZE=$(du -s ~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/com.apple.mediaanalysisd | awk '{print $1}') ##Get cache size in KB

SIZE=$((SIZE/2)) ##SIZE was being doubled. If the file size is wrong, this line may no longer be needed...



ACTUAL=$(($LIMIT*1000000)) ##Convert to KB for size comparison

if ((SIZE>=ACTUAL)); then

    echo 'mediaanalysisd cache is greater than '"$LIMIT"'GB...'

    rm -rfd ~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/com.apple.mediaanalysisd

    echo 'mediaanalysisd cache has been deleted!'

else

    echo 'mediaanalysisd cache is smaller than '"$LIMIT"'GB...'

fi
