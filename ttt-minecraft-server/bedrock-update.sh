#!/bin/bash

DOWNLOAD="/opt/bedrock"
# SERVER以下にあるbedrock-serverディレクトリにサーバーのファイルを展開する
SERVER="/opt/bedrock"

BASE_URL="https://minecraft.net/en-us/download/server/bedrock/"

# AGENT無しでcurlするとアクセスを拒否されるので、Agentを付与する
# このAgentだと行けるけどなんで行けるのかわからん...
AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.33 (KHTML, like Gecko) Chrome/90.0.0.212 Safari/537.33"
# HTMLからダウンロードURLを取ってくる(for Linux)
URL=`curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "${AGENT}" ${BASE_URL} 2>/dev/null | grep bin-linux | sed -e 's/.*<a href=\"\(https:.*\/bin-linux\/.*\.zip\).*/\1/'`

# サーバーのzipファイル
FILE_PATH=${DOWNLOAD}/${URL##*/}

echo "URL=${URL}"
echo "FILE_PATH=${FILE_PATH}"

# backupディレクトリがなければ作成
mkdir -p ${SERVER}/backup

if [ -f ${FILE_PATH} ]; then
    # 同じファイルがある場合は更新不要なので何もしない
    echo "Already Updated."
else
    # 同じファイルがない場合は更新があるのでアップデート実行
    echo "Update found, start update..."

    # 既存の設定をbackupに退避
    cp ${SERVER}/bedrock-server/server.properties ${SERVER}/backup/
    cp ${SERVER}/bedrock-server/permissions.json ${SERVER}/backup/
    cp ${SERVER}/bedrock-server/allowlist.json ${SERVER}/backup/

    # サーバーのzipファイルをダウンロード
    curl ${URL} --output ${FILE_PATH}

    # サーバーのzipファイルをbedrock-server以下に展開
    unzip -oq ${FILE_PATH} -d ${SERVER}/bedrock-server

    # 退避させていた設定ファイルを戻す
    cp ${SERVER}/backup/server.properties ${SERVER}/bedrock-server/
    cp ${SERVER}/backup/permissions.json ${SERVER}/bedrock-server/
    cp ${SERVER}/backup/allowlist.json ${SERVER}/bedrock-server/
fi

exit