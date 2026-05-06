# In the original repository we'll just print the result of status checks,
# without committing. This avoids generating several commits that would make
# later upstream merges messy for anyone who forked us.
commit=true
origin=$(git remote get-url origin)
if [[ $origin == *statsig-io/statuspage* ]]
then
  commit=false
fi

KEYSARRAY=()
URLSARRAY=()

urlsConfig="./urls.cfg"
echo "Reading $urlsConfig"
while read -r line
do
  echo "  $line"
  IFS='=' read -ra TOKENS <<< "$line"
  KEYSARRAY+=(${TOKENS[0]})
  URLSARRAY+=(${TOKENS[1]})
done < "$urlsConfig"

echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

mkdir -p logs

for (( index=0; index < ${#KEYSARRAY[@]}; index++))
do
  key="${KEYSARRAY[index]}"
  url="${URLSARRAY[index]}"
  echo "  $key=$url"

  response="000"
  result="failed"
  for i in 1 2 3 4; 
  do
    response=$(curl --connect-timeout 10 --max-time 30 --write-out '%{http_code}' --silent --output /dev/null "$url" || true)
    if [[ -z "$response" ]]; then
      response="000"
    fi
    if [[ "$response" =~ ^(200|202|301|302|307|401|403)$ ]]; then
      result="success"
    else
      result="failed"
    fi
    if [ "$result" = "success" ]; then
      break
    fi
    sleep 5
  done

  reportFile="logs/${key}_report.log"
  previousFailures=0
  if [[ -f "$reportFile" ]]
  then
    previousLine=$(tail -1 "$reportFile")
    if [[ "$previousLine" =~ consecutive_failures=([0-9]+) ]]
    then
      previousFailures="${BASH_REMATCH[1]}"
    elif [[ "$previousLine" =~ failed|suspected ]]
    then
      previousFailures=1
    fi
  fi

  if [ "$result" = "success" ]; then
    consecutiveFailures=0
    finalResult="success"
  else
    consecutiveFailures=$((previousFailures + 1))
    if [ "$consecutiveFailures" -ge 3 ]; then
      finalResult="failed"
    else
      finalResult="suspected"
    fi
  fi

  dateTime=$(date +'%Y-%m-%d %H:%M')
  logLine="$dateTime, $finalResult, http=$response, consecutive_failures=$consecutiveFailures"
  if [[ $commit == true ]]
  then
    echo "$logLine" >> "$reportFile"
    # By default we keep 2000 last log entries.  Feel free to modify this to meet your needs.
    echo "$(tail -2000 "$reportFile")" > "$reportFile"
  else
    echo "    $logLine"
  fi
done

if [[ $commit == true ]]
then
  # Let's make Vijaye the most productive person on GitHub.
  git config --global user.name 'Vijaye Raji'
  git config --global user.email 'vijaye@statsig.com'
  git add -A --force logs/
  git commit -m '[Automated] Update Health Check Logs' || true
  git push
fi
