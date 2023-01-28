JIRAチケットとGoogleカレンダーの予定から今日の予定ファイルを作成するスクリプトです

## usage
```bash
./yotei.sh ${前営業日:-yesterday}
```

## prerequirement
- jira api token
- google oauth client
- python3
### JIRA API の使用準備
JIRAチケット情報の取得にはJIRAのAPIトークンと取得対象のスプリントボードIDを取得する必要があります
APIトークンは[JIRAのドキュメント](https://support.atlassian.com/ja/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/)を参考にしてください
スプリントボードのIDはスプリントボードを開いた際のURLの末尾の数字です(/boards/${id})
それぞれ確認出来たら./secrets/secret.json に以下のようなjsonを作成してください
```bash
{
  "JIRAUrl": "https://example.com",
  "JIRAApiToken": "hogehoge",
  "emailAddress": "email@example.com",
  "projects": [
    {
      "name": "hogehogeプロジェクト",
      "JIRABoardId": "${boardid}",
      "calendarEmail": "${プロジェクト用google calendarのメールアドレス}"
    }
  ]
}
```

### google projectの準備
googleカレンダーの予定を取得するにはgoogleのOauthクライアントの設定が必要です
[Googleのドキュメント](https://developers.google.com/calendar/api/quickstart/python?hl=ja)を参考に以下の手順を行ってください
1. google cloudプロジェクトの作成
    - [Googleのドキュメント](https://developers.google.com/workspace/guides/create-project?hl=ja)を参考にプロジェクトを作成してください。
2. APIの有効化
    - [Google Cloud Console](https://console.cloud.google.com/flows/enableapi?apiid=calendar-json.googleapis.com&hl=ja)からGoogle Calendar APIを有効にしてください
3. 認証情報jsonのダウンロード
    - Googleのドキュメントの[この項目](https://developers.google.com/calendar/api/quickstart/python?hl=ja#authorize_credentials_for_a_desktop_application)を参考に、Oauthクライアントを作成し、認証情報のjsonをダウンロードしてください。
    - ダウンロードしたjsonは`./secrets/google_credentials.json`に保存してください
4. クライアントライブラリのインストール
    ```bash
    pip install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib
    ```