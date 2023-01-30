#!/bin/bash
set -eu

lastDay="${1:-yesterday}"
secretJSON=$(cat ./secrets/secret.json)
JIRAUrl=$(echo -n "$secretJSON" | jq -r .JIRAUrl)
JIRAApiToken=$(echo -n "$secretJSON" | jq -r .JIRAApiToken)
emailAddress=$(echo -n "$secretJSON" | jq -r .emailAddress)
accessToken=$(echo -n ${emailAddress}:${JIRAApiToken} | base64)
useMarkup=false

function main() {
  nippouDir=$(date "+%Y%m")
  mkdir -p ${nippouDir}
  nippouFile=${nippouDir}/$(date "+%Y%m%d")予定.md
  : >| $nippouFile
  
  if [ -f ./secrets/google_credentials.json ]; then
    python3 src/google_oauth.py
  fi

  IFS=$'\n'; for project in $(echo $secretJSON | jq -c '.projects[]'); do
    projectName=$(echo $project | jq -r .name)
    projectJIRABoardId=$(echo $project | jq -r .JIRABoardId)
    projectCalendarEmail=$(echo $project | jq -r .calendarEmail)
    echo $projectName >> $nippouFile
    if [ -n "$JIRAApiToken" ]; then
      outputTicketStatus $useMarkup $projectJIRABoardId >> $nippouFile
    fi
    if [ -f ./secrets/google_token.json ]; then
      outputEvent $useMarkup $projectCalendarEmail $(date -d "${lastDay}" '+%Y-%m-%dT00:00:00%:z') $(date '+%Y-%m-%dT23:59:59%:z') "" >> $nippouFile
    fi
    echo "" >> $nippouFile
  done
  if [ -f ./secrets/google_token.json ]; then
    echo "その他" >> $nippouFile
    outputEvent $useMarkup $emailAddress $(date -d "${lastDay}" '+%Y-%m-%dT00:00:00%:z') $(date '+%Y-%m-%dT23:59:59%:z') "$(echo $secretJSON | jq -c '[.projects[].calendarEmail]')" >> $nippouFile
  fi
}

function outputTicketStatus() {
  useMarkup="$1"
  JIRABoardId="$2"
  getTicketStatus $JIRABoardId | jq '
    if .status == "done" then
      .flagStr="- v"
    elif .status == "indeterminate" then
      .flagStr="- vo"
    elif .status == "new" then
      .flagStr="- o"
    else
      .flagStr=""
    end |
    {
      flagStr: .flagStr,
      markedStr: ("["+ .key +"]" +"("+ .url +")" + " " + .title),
      normalStr: (.key + " " + .title)
    }' \
  | jq -r "if ${useMarkup} then
      .flagStr + \" \" + .markedStr
    else
      .flagStr + \" \" + .normalStr
    end" \
  | sort -V -r
}

function getTicketStatus() {
  JIRABoardId="$1"
  currentSprintUrl=$(curl -sS --request GET \
    --url "${JIRAUrl}/rest/agile/1.0/board/${JIRABoardId}/sprint?state=active" \
    --header "Authorization: Basic ${accessToken}" \
    --header 'Accept: application/json' | jq .values[0].self -r)

  curl -sS --request GET \
    --url "${currentSprintUrl}/issue?maxResults=1000" \
    --header "Authorization: Basic ${accessToken}" \
    --header 'Accept: application/json' \
  | jq ".issues[] |
    select(.fields.assignee.emailAddress == \"${emailAddress}\") |
    {
      title: .fields.summary,
      status: .fields.status.statusCategory.key,
      key: .key,
      url: (\"${JIRAUrl}/browse/\" + .key)
    }" 
}

function outputEvent() {
  useMarkup="$1"
  calendarEmail="$2"
  endMin="$3"
  startMax="$4"
  exceptCalendarEmails="${5:-[]}"
  getEvent $calendarEmail $endMin $startMax "$exceptCalendarEmails" | jq '
    if .end <= (now | strflocaltime("%FT%X+09:00")) then
      .flagStr="- v"
    else
      .flagStr="- o"
    end |
    {
      flagStr: .flagStr,
      markedStr: ("["+ .title +"]" +"("+ .meet +")" + " " + (.start | strptime("%FT%X+09:00")|strftime("%X")) + "-"+(.end | strptime("%FT%X+09:00")|strftime("%X"))),
      normalStr: (.title + " " + (.start | strptime("%FT%X+09:00")|strftime("%X")) + "-"+(.end | strptime("%FT%X+09:00")|strftime("%X")))
    }' \
  | jq -r "if ${useMarkup} then
      .flagStr + \" \" + .markedStr
    else
      .flagStr + \" \" + .normalStr
    end" \
  | sort -V -r

}

function getEvent() {
  calendarEmail="$1"
  endMin="$2"
  startMax="$3"
  exceptCalendarEmails="$4"
  apiToken=$(cat ./secrets/google_token.json| jq -r .token)
  curl -sS \
    "https://www.googleapis.com/calendar/v3/calendars/primary/events?singleEvents=true&orderBy=startTime&timeMax=$(echo -n $startMax | sed 's/:/%3A/g' | sed 's/+/%2B/g' )&timeMin=$(echo -n $endMin | sed 's/:/%3A/g' | sed 's/+/%2B/g')" \
    --header "Authorization: Bearer ${apiToken}" \
    --header 'Accept: application/json' \
    --compressed | jq ".items[] |
      select(
        .organizer.email == \"${calendarEmail}\" or
        .attendees != null and ([.attendees[].email] | contains([\"${calendarEmail}\"]))
      ) |
      select(
        ([.organizer.email] - (${exceptCalendarEmails}) == [.organizer.email]) and
        (.attendees != null and ([.attendees[].email] - ${exceptCalendarEmails} == [.attendees[].email]))
      ) |
      {
        title : .summary,
        start : .start.dateTime,
        end : .end.dateTime,
        meet : select(.conferenceData != null) | .conferenceData.entryPoints[] | select(.entryPointType == \"video\") | .uri
      }"
}

main
