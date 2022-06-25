#!/bin/bash

# https://vpslife.server-memo.net/ubuntu_bedrock_minecraft_install/

USERNAME='ubuntu'
SESSION_NAME='bedrock'

BEDROCK_PATH='/opt/bedrock/bedrock-server'
LD_LIBRARY_PATH="$BEDROCK_PATH"
SERVICE="$BEDROCK_PATH/bedrock_server"

## バックアップ用設定
# バックアップ格納ディレクトリ
BK_DIR="/home/$USERNAME/bedrock_backup"
 
# バックアップ取得時間
BK_TIME=`date +%Y%m%d-%H%M%S`
 
# 完全バックアップデータ名
FULL_BK_NAME="$BK_DIR/bedrock_full_backup_${BK_TIME}.tar.gz"
 
# 簡易パックアップデータ名
SIMPLE_BK_NAME="$BK_DIR/bedrock_simple_backup_${BK_TIME}.tar"
 
# 簡易バックアップ対象データ
BK_FILE="$BEDROCK_PATH/worlds \
  $BEDROCK_PATH/valid_known_packs.json \
  $BEDROCK_PATH/permissions.json \
  $BEDROCK_PATH/server.properties \
  $BEDROCK_PATH/whitelist.json"
 
# バックアップデータ保存数
BK_GEN="3"
 
cd $BEDROCK_PATH
 
if [ ! -d $BK_DIR ]; then
  mkdir $BK_DIR
fi
 
ME=`whoami`
 
if [ $ME != $USERNAME ]; then
  echo "Please run the $USERNAME user."
  exit
fi
 
# 開始
start() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null; then
    echo "$SERVICE is already running!"
  else
    echo "Starting $SERVICE..."
    tmux new-session -d -s $SESSION_NAME
    tmux send-keys -t $SESSION_NAME:0 "LD_LIBRARY_PATH=$LD_LIBRARY_PATH $SERVICE" C-m
  fi
}
 
# 停止
stop() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null; then
    echo "Stopping $SERVICE"
    tmux send-keys -t $SESSION_NAME:0 "say SERVER SHUTTING DOWN IN 10 SECONDS. Saving map..." C-m
    sleep 10
    tmux send-keys -t $SESSION_NAME:0 "stop" C-m
    sleep 10
    echo "Stopped bedrock_server"
  else
    echo "$SERVICE is not running!"
    exit
  fi
   while :
   do
     if
      pgrep -u $USERNAME -f $SERVICE > /dev/null; then
      echo "Stopping $SERVICE"
      sleep 10
    else
      tmux kill-session -t $SESSION_NAME
      echo "Stoped $SERVICE"
      break
    fi
  done
}
 
# 簡易バックアップ
s_backup() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null; then
    echo "Backup start minecraft data..."
    tmux send-keys -t $SESSION_NAME:0 "save hold" C-m
    sleep 10
    tmux send-keys -t $SESSION_NAME:0 "save query " C-m
    tar cfv $SIMPLE_BK_NAME $BK_FILE
    sleep 10
    tmux send-keys -t $SESSION_NAME:0 "save resume" C-m
    echo "bedrock_server backup compleate!"
    gzip -f $SIMPLE_BK_NAME
    find $BK_DIR -name "bedrock_simple_backup_*.tar.gz" -type f -mtime +$BK_GEN -exec rm {} \;
  else
    echo "Backup start ..."
    gzip -f $HOUR_BK_NAME
    find $BK_DIR -name "bedrock_simple_backup_*.tar.gz" -type f -mtime +$BK_GEN -exec rm {} \;
  fi
 }
 
# 完全バックアップ
f_backup() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null; then
    echo "Full backup start minecraft data..."
    tmux send-keys -t $SESSION_NAME:0 "say SERVER SHUTTING DOWN IN 10 SECONDS. Saving map..." C-m
    sleep 10
    tmux send-keys -t $SESSION_NAME:0 "save-all" C-m
    tmux send-keys -t $SESSION_NAME:0 "stop" C-m
    while :
      do
        if
          pgrep -u $USERNAME -f $SERVICE > /dev/null; then
          echo "Stopping $SERVICE"
          sleep 10
        else
          echo "Stopped bedrock_server"
          echo "Full Backup start ..."
          tar cfvz $FULL_BK_NAME $BEDROCK_PATH
          echo "Full Backup compleate!"
          find $BK_DIR -name "bedrock_full_backup_*.tar.gz" -type f -mtime +$BK_GEN -exec rm {} \;
          break
        fi
      done
    echo "Starting $SERVICE..."
    tmux send-keys -t $SESSION_NAME:0 "$SERVICE" C-m
  else
    echo "Full Backup start ..."
    tar cfvz $FULL_BK_NAME $BEDROCK_PATH
    echo "Full Backup compleate!"
    find $BK_DIR -name "bedrock_full_backup_*.tar.gz" -type f -mtime +$BK_GEN -exec rm {} \;
  fi
}
 
# 起動状態確認
status() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null; then
    echo "$SERVICE is already running!"
    exit
  else
    echo "$SERVICE is not running!"
    exit
  fi
}
 
case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  s_backup)
    s_backup
    ;;
  f_backup)
    f_backup
    ;;
  status)
    status
    ;;
  *)
    echo  $"Usage: $0 {start|stop|s_backup|f_backup|status}"
esac


