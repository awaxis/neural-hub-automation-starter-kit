# Server Data Backup to Google Drive

All the following service data are backed up daily at midnight (UTC) to the Google Drive backup folder, using the Rclone tool.

* AFFiNE
* PostgreSQL
* n8n

***Assume that Rclone is installed and Google Drive is properly configured.***


The script **`/opt/tools/rclone/rclone-task-executor.sh`** is daily executed by the system daemon timer with the configuration below.

**`/opt/tools/rclone/sync-task.timer`**

```ini
[Unit]
Description=Timer that periodically triggers the sync-task.service

[Timer]
OnCalendar=00:00

[Install]
WantedBy=timers.target
```

**`/opt/tools/rclone/sync-task.service`**

```ini
[Unit]
Description=Daily synchronisation task of tools data

[Service]
Type=oneshot
ExecStart=sh /opt/tools/rclone/rclone-task-executor.sh -d=/home/ubuntu/tools
#User=dedicated-user
#Group=dedicated-user
```


The configuration file should be placed in **`/etc/systemd/system`****&#x20;**, to do so, symbolic links are created:

```shell
ln -s /opt/tools/rclone/sync-task.service /etc/systemd/system/rclone-sync-task.service
ln -s /opt/tools/rclone/sync-task.timer /etc/systemd/system/rclone-sync-task.timer
```

Then, enable the task timer after reloading the systemctl daemon to discover the new added service:

```shell
sudo systemctl daemon-reload
sudo systemctl enable rclone-sync-task.timer
```

## Enable Folder Backup

To enable backup of a specific folder, add an `.rclone-task` file with `rclone` commands to it.

The backup script scans the folders in the specified --data-dir looking for an `.rclone-task` and executes the `Rclone` tasks. Only one level is scanned.

**Note**: Lines starting with # are comments, and empty lines will be ignored.



Example of `.rclone-task` file for AFFiNE backup:

```shell
# Synchronize Affine Data storage to Google Drive
sync /home/ubuntu/tools/affine/storage gdrive:Servers/srv01/tools/affine/storage --min-age=5m --exclude="*/log/*.log"
# Synchronize Affine configs
sync /home/ubuntu/tools/affine/config gdrive:Servers/srv01/tools/affine/config --min-age=5m
```



## Backup Script

The `rclone-task-executor.sh` 

```shell
#!/bin/sh

# Shell script to execute Rclone Sync or Copy tasks
# Each data folder should contain a .rclone-task file with rclone commands
# Example .rclone-task file content:
# sync /path/to/local/dir gdrive:remote/dir
# copy /path/to/local/dir gdrive:remote/dir
# Lines starting with # are comments and will be ignored
# Empty lines will also be ignored
# Usage: sh ./rclone-task-executor.sh -d=/path/to/data/dir [-p] [-e=*.tmp] [-a=1h] [-A=1d]
# Options:
#   -d|--data-dir       The directory containing data folders to sync (required)
#   -p|--progress       Show progress during transfer (optional)
#   -e|--exclude        Exclude files matching the pattern (e.g., *.tmp) (optional)
#   -a|--min-age       Only include files older than the specified duration (e.g., 30m, 1h, 1d) (optional)
#   -A|--max-age       Only include files younger than the specified duration (e.g., 30m, 1h, 1d) (optional)
#   --h|--help          Show help message and exit

set -e
#set -u

usage() {
  cat <<USAGE
Rclone Sync Script
Usage:
 $ sh ./rclone-task.sh -d|--data-dir [-p|--progress] [-e|--exclude] [-a|--min-age] [-A|--max-age] [-h|--help]
    -d=*|--data-dir=*                 The directory containing data folders to sync
    -p|--progress                     Show progress during transfer
    -e=*|--exclude=*                  Exclude files matching the pattern (e.g., *.tmp)
    -a=*|--min-age=*                  Only include files older than the specified duration (e.g., 30m, 1h, 1d)
    -A=*|--max-age=*                  Only include files younger than the specified duration (e.g., 30m, 1h, 1d)
    -h|--help                         Show this help and exit

Examples:
# Sync all data folders in /path/to/data/dir with progress
sh ./rclone-task.sh -d=/path/to/data/dir -p
# Sync all data folders in /path/to/data/dir excluding .tmp files
sh ./rclone-task.sh -d=/path/to/data/dir -e=*.tmp
# Sync all data folders in /path/to/data/dir including only files older than 1 hour
sh ./rclone-task.sh -d=/path/to/data/dir -a=1h
# Sync all data folders in /path/to/data/dir including only files younger than 1 day
sh ./rclone-task.sh -d=/path/to/data/dir -A=1d
USAGE
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

is_true() {
  if [ $(echo $1 | tr '[A-Z]' '[a-z]') =~ ^y|^yes|^true ]; then
    return 0
  else
    return 1
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--progress)
      PROGRESS="--progress"
      ;;
    -e=*|--exclude=*)
      EXCLUDE="--exclude=‘${1#*=}‘"
      ;;
    -a=*|--min-age=*)
      MIN_AGE="--min-age=${1#*=}"
      ;;
    -A=*|--max-age=*)
      MAX_AGE="--max-age=${1#*=}"
      ;;
    -d=*|--data-dir=*)
      DATA_DIR="${1#*=}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [ -z "$DATA_DIR" ]; then
  echo "Error: Missing data directory argument."
  usage
  exit 1
fi
if [ ! -d "$DATA_DIR" ]; then
  echo "Error: Data directory '$DATA_DIR' does not exist."
  exit 1
fi

# Ensure rclone is installed
if [ -z $(command -v rclone &> /dev/null) ]; then
  echo "Error: rclone is not installed. Please install rclone and try again."
  exit 1
fi

# Ensure rclone remote is configured
if ! rclone listremotes | grep -q '^gdrive:$'; then
  echo "Error: rclone remote 'gdrive' is not configured. Please configure it and try again."
  exit 1
fi

TASK_NUM=0

for i in $DATA_DIR/*
do
  if [ -d "$i" ]; then
    if ! [ -e "$i/.rclone-task" ]; then
      continue
    fi

    echo "$(date +'%Y-%m-%d %H:%M:%S') - Start synchronizing $( basename "$i" )..."
    while IFS= read -r task;
    do
        case "$task" in
            \#*) ;;  # Skip comment lines
            '') ;;   # Skip empty lines
            *)
                if echo "$task" | grep -q '^\(sync\|copy\) '; then
                    echo "$(date +'%Y-%m-%d %H:%M:%S') - Executing: rclone $task $EXCLUDE $MIN_AGE $MAX_AGE $PROGRESS"
                    rclone $task $EXCLUDE $MIN_AGE $MAX_AGE $PROGRESS
                else
                    echo "Warning: Invalid rclone task: '$task'. Skipping..."
                fi
            ;;
        esac
    done < "$i/.rclone-task"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Finished synchronizing $( basename "$i" )..."
    TASK_NUM=$((TASK_NUM + 1))
  fi
done

if [ $TASK_NUM -eq 0 ]; then
  echo "No valid data folders found to sync in '$DATA_DIR'."
else
  echo "All $TASK_NUM tasks completed."
fi

```

Credits:  awaxis

