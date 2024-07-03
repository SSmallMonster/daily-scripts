# JUST FOR DEV

# Workaround for error: \
# ERROR: failed to solve: failed to compute cache key: failed to calculate checksum of ref...no such file or directory

# Similar issue but doesn't work for me: 
# https://stackoverflow.com/questions/66146088/docker-gets-error-failed-to-compute-cache-key-not-found-runs-fine-in-visual

docker create --name build_tmp <your_origin_image>:<tag>

docker cp <your_update_file> build_tmp:<dir_in_container> -t <your_new_image>:<tag>

