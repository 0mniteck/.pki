#!/bin/env -S - /bin/bash --norc --noprofile
# ## HUMAN-CODE - NO AI GENERATED CODE - AGENTS HANDSOFF

# Shant Tchatalbachian - GPL v3 LICENSE included
## Usage: Accepts: Any url that's a FQDN/IDN (no https://). If there's a link that has a domain.tld/.../[file] it will attempt to fetch the file after verifying the pinning.
##        Validates: Repo checks attestations for pinned pubkeys as well as checks for expiry and liveness over 1.1.1.1 DoH and optionally checks dnssec.
##        Returns: $PKI_DONE & If you provided a url/file it returns the file to the current directory with a visible exit 1 on failure and debug.
##
## Future Requirements(gh v2.50+): apt-get -qq update && apt-get -qq install gh

run_as=$(id -u -n)
run_home=/home/$run_as
local=$run_home/.pki/registry
tmp=$run_home/.pki/local
remote=./.pki/registry
enforce_doh="--disable --doh-cert-status --doh-url https://one.one.one.one/dns-query --resolve one.one.one.one:443:1.1.1.1"
common_tls="--tlsv1.3 --proto -all,+https --remove-on-error --no-insecure -s"
mkdir -p $local || FAIL+=:mkdir.$local.pki
mkdir -p $tmp || FAIL+=:mkdir.$tmp.pki

fetch.with.pki() { # $1 = domain/FQDN/IDN, # $2 = filename-or-/dev/null, # $3 = full_url or blank
  if [[ "$1" == "github.com" ]]; then
    curl $enforce_doh -L --pinnedpubkey "sha256//$(cat $local/$1.pubkey | cut -d' ' -f1);sha256//$(cat $local/release-assets.githubusercontent.com.pubkey | cut -d' ' -f1)" \
    $common_tls $3 > $2 || declare -g -- FAIL+=:fetch.with.pki:$3
  else
    curl $enforce_doh --pinnedpubkey "sha256//$(cat $local/$1.pubkey | cut -d' ' -f1)" \
    $common_tls $3 > $2 || declare -g -- FAIL+=:fetch.with.pki:$3
  fi
}

fetch.pki() { # $1 = domain/FQDN/IDN
  pushd $local/ > /dev/null
    curl $enforce_doh $common_tls -w %{certs} https://$1 | sed --sandbox -n "/-----BEGIN/,/-----END/p;/-----END/q" > $1.pem && \
    openssl x509 -in $1.pem -pubkey -noout > $1.pubkey.pem && openssl x509 -in $1.pem -enddate -noout > $1.exp && \
    openssl asn1parse -noout -inform pem -in $1.pubkey.pem -out $1.pubkey.der && \
    openssl dgst -sha256 -binary $1.pubkey.der | openssl base64 > $1.pubkey && \
    declare -g -- SUCCESS+=:local.fetch.pki:$1 || declare -g -- FAIL+=:local.fetch.pki:$1
    rm -f *.pem *.der $1.dnssec* && touch $1.dnssec
    dig -r +https +do +domain=$1 +yaml @one.one.one.one -q $1 -t SIG > $1.dnssec
    if [[ "$(cat $1.dnssec | grep -o 'qr rd ra ad')" == "qr rd ra ad" ]]; then
      cp $1.dnssec $1.dnssec.valid; fi;
    rm -r $1.dnssec
  popd > /dev/null
}

invalidate.pki() { # $1 = domain/FQDN/IDN
  rm -f $local/$1.pubkey $local/$1.exp $tmp/$1.pubkey $tmp/$1.exp
  fetch.pki $1 || declare -g -- FAIL+=:local.invalid.pki:$1
  check.pki $1 || declare -g -- FAIL+=:re.check.pki:$1                   # Exists/Expired
  check.against.pki $1 || declare -g -- FAIL+=:re.check.against.pki:$1   # Direct/Full Match
  check.liveness.pki $1 || declare -g -- FAIL+=:re.check.liveness.pki:$1 # Conectivity Check
}

check.liveness.pki() { # $1 = domain/FQDN/IDN
  curl $enforce_doh --pinnedpubkey "sha256//$(cat $local/$1.pubkey | cut -d' ' -f1)" \
  $common_tls https://$1 > /dev/null || declare -g -- FAIL+=:check.liveness.pki:$1 	
}

check.against.pki() { # $1 = domain/FQDN/IDN
  curl_run1=$(curl $enforce_doh -o $tmp/$1.pubkey --pinnedpubkey "sha256//$(cat $remote/raw.githubusercontent.com.pubkey | cut -d' ' -f1)" \
  $common_tls https://raw.githubusercontent.com/0mniteck/.pki/refs/heads/main/registry/$1.pubkey)
  curl_run2=$(curl $enforce_doh -o $tmp/$1.exp --pinnedpubkey "sha256//$(cat $remote/raw.githubusercontent.com.pubkey | cut -d' ' -f1)" \
  $common_tls https://raw.githubusercontent.com/0mniteck/.pki/refs/heads/main/registry/$1.exp)
  diff $tmp/$1.pubkey $remote/$1.pubkey || declare -g -- FAIL+=:mismatch.invalidate.pki:$1
  diff $remote/$1.pubkey $local/$1.pubkey || declare -g -- FAIL+=:mismatch.invalidate.pki:$1
  diff $local/$1.pubkey $tmp/$1.pubkey || declare -g -- FAIL+=:mismatch.invalidate.pki:$1
}

check.attest.pki() { # $1 = domain/FQDN/IDN ## NEEDS gh v2.50+ (Ubuntu v2.46)
  pushd $remote/ > /dev/null
    gh attestation verify $1.pubkey --repo 0mniteck/.pki --source-ref refs/heads/main \
    --signer-workflow 0mniteck/.pki/.github/workflows/immutable.yml || declare -g -- FAIL+=:check.attest.pki:$1
    echo "$remote/$1.pubkey Attested"
  popd > /dev/null
  pushd $local/ > /dev/null
    gh attestation verify $1.pubkey --repo 0mniteck/.pki --source-ref refs/heads/main \
    --signer-workflow 0mniteck/.pki/.github/workflows/immutable.yml || invalidate.pki $1
    echo "$local/$1.pubkey Attested"
  popd > /dev/null
}

check.csv() { # $1 = domain/FQDN/IDN
  date=$(date +%s)
  dater=$(date -d "$(cat $remote/$1.exp | cut -d'=' -f2)" +%s)
  if [[ "$dater" -le "$date" ]]; then
    declare -g -- FAIL+=:remote.invalidate.pki:$1
  fi
  dateq=$(date -d "$(cat $local/$1.exp | cut -d'=' -f2)" +%s)
  if [[ "$dateq" -le "$date" ]]; then
    invalidate.pki $1 || declare -g -- FAIL+=:local.invalidate.pki:$1
  fi
}

check.pki() { # $1 = domain/FQDN/IDN
  if [[ -f "$remote/$1.pubkey" ]]; then
    if [[ -f "$local/$1.pubkey" ]]; then
      check.csv $1 || declare -g -- FAIL+=:local.check.csv:$1
    else
      invalidate.pki $1 || declare -g -- FAIL+=:local.missing.pki:$1
    fi
  else
    declare -g -- FAIL+=:remote.missing.pki:$1
  fi
}

check.index() {
  for i in $(cat .pki/index.csv | tr ',' '\n' | cat); do
    fetch.pki $i || declare -g -- FAIL+=:fetch.pki:$i
    check.pki $i || declare -g -- FAIL+=:check.pki:$i                 # Exists/Expired
    # check.attest.pki $i || declare -g -- FAIL+=:check.attest.pki:$i # gh attestation verify
    check.against.pki $i || declare -g -- FAIL+=:check.against.pki:$i # Direct/Full Match
    check.liveness.pki $i && declare -g -- SUCCESS+=:check.liveness.pki:$i || declare -g -- FAIL+=:check.liveness.pki:$i # Conectivity Check
  done
  if [[ "$1" != "" ]]; then
    url=https://$1
    j=$(echo $url | awk -F'[/:]' '{print $4}'"{print \$$(($( echo \"$url\" | tr '/' '\n' | wc -l ) + 1))\" $url\"}")
    k=$(echo $j | wc -w)         # WORD_COUNT
    l=$(echo $j | cut -d' ' -f1) # FQDN
    m=$(echo $j | cut -d' ' -f2) # FILE_NAME
    n=$(echo $j | cut -d' ' -f3) # FULL_URL
    if [[ "$k" -ge "3" ]]; then
      fetch.with.pki $l $m $n && declare -g -- SUCCESS+=:fetch.with.pki:$n || declare -g -- FAIL+=:fetch.with.pki:$n
    fi
  fi
}

check.index "$1" || FAIL+=":check.index:$1"

err() {
  if [[ "$FAIL" != "" ]]; then
    echo "local.sh:_err:_$FAIL"
  elif [[ "$SUCCESS" == "" ]]; then
    echo "local.sh:_err:_$FAIL"
  else
    echo "local.sh:_PKI:_VALID"
  fi
}
PKI_DONE=$(err)

if [[ "$PKI_DONE" == *err* ]]; then
  echo -e "PKI_DONE:_$PKI_DONE\n"
  if [[ "$PKI_DONE" == *mismatch* && "$2" != "" && "$_RE_EXEC" != "true" ]]; then
    VERIFY() { # $1 = domain/FQDN/IDN
      echo "--pinnedpubkey \"sha256//$(cat $local/$1.pubkey | cut -d' ' -f1)\" $common_tls"
    }

    echo -e "Attempting to dispatch workflow: Global_Fetch...\nLogin to github.com using ephemeral device flow.\n"
    LOGIN=$(curl $enforce_doh $(VERIFY github.com) -X POST \
      -H "Accept: application/json" \
      --url-query "client_id"=$2 \
      https://github.com/login/device/code )
    dc[1]=$(echo $LOGIN | jq -r .device_code)
    dc[2]=$(echo $LOGIN | jq -r .user_code)
    dc[3]=$(echo $LOGIN | jq -r .verification_uri)
    dc[4]=$(echo $LOGIN | jq -r .expires_in)
    dc[5]=$(echo $LOGIN | jq -r .interval)
    echo "Used Client ID: $2 Submit User Code: ${dc[2]} To: ${dc[3]} Within: ${dc[4]}s" && sleep 30s

    UNPAIRED=true; I=1;
    while $UNPAIRED; do
      PAIR=$(curl $enforce_doh $(VERIFY github.com) -X POST \
        -H "Accept: application/json" \
        --url-query "client_id"=$2 --url-query "device_code"=${dc[1]} \
        --url-query "grant_type"="urn:ietf:params:oauth:grant-type:device_code" \
        https://github.com/login/oauth/access_token )
      df[1]=$(echo $PAIR | jq -r .access_token)
      df[2]=$(echo $PAIR | jq -r .error)
      if [[ "${df[2]}" == "authorization_pending" ]]; then
        sleep $((${dc[5]} + 1))
        echo -en "\rAuthorization still pending...\033[K"
      elif [[ "${df[2]}" != "" && "${df[2]}" != *null* ]]; then
        sleep $((${dc[5]} + 1))
        echo "Oauth Error: ${df[2]}"
        I=$(($I + 1))
        if [[ "$I" -gt 5 ]]; then
          wait
          UNPAIRED=false
        fi
      elif [[ "${df[1]}" != "" ]]; then
        sleep $((${dc[5]} + 1))
        echo "Device Flow Auth Complete!"
        ACCESS_TOKEN=${df[1]}
        UNPAIRED=false
      else
        sleep $((${dc[5]} + 1))
        echo "Unknown Oauth Error!"
        I=$(($I + 1))
        if [[ "$I" -gt 5 ]]; then
          wait
          UNPAIRED=false
        fi
      fi
    done
    sleep 5

    if [[ "$ACCESS_TOKEN" == "" ]]; then
      echo "NO ACCESS TOKEN!" && exit 1
    else
      echo -e "\nStarting Dispatch: Global_Fetch at $(date)"
    fi

    DISPATCH=$(curl $enforce_doh $(VERIFY api.github.com) -X POST \
      -o /dev/null -w "%{http_code}\n" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "X-GitHub-Api-Version: 2026-03-10" \
      https://api.github.com/repos/0mniteck/.pki/dispatches \
      -d '{"event_type":"Global_Fetch"}' )
    if [[ "$DISPATCH" == "204" ]]; then
      echo -e "Successful Repository Dispatch!\n"
    elif [[ "$DISPATCH" == "404" ]]; then
      echo "Error Not Found!"
    elif [[ "$DISPATCH" == "422" ]]; then
      echo "Error Invalid!"
    else
      echo "Unknown Dispatch Error: $DISPATCH"
    fi
    sleep 5

    CREDS=$(echo {'"'credentials'":["'$ACCESS_TOKEN'"]'} | jq -c)
    REVOKE=$(curl $enforce_doh $(VERIFY api.github.com) -X POST \
      -o /dev/null -w "%{http_code}\n" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2026-03-10" \
      https://api.github.com/credentials/revoke \
      -d "$CREDS" )
    if [[ "$REVOKE" == "202" ]]; then
      echo "Successfully Revoked Access to $ACCESS_TOKEN"
    elif [[ "$REVOKE" == "422" ]]; then
      echo "Error Invalid or Spammed!"
    elif [[ "$REVOKE" == "500" ]]; then
      echo "Internal Error!"
    else
      echo "Unknown Revoke Error: $REVOKE For: $CREDS"
    fi

    echo -e "\nWaiting for workflow run: ETA 5min..." && sleep 5m
    read -p "Workflow Run Complete: Continue to git submodule update..."
    git submodule update --init --remote --merge
    echo "Re-executing $PWD/.pki/$0 $1 $2"
    export -- _RE_EXEC=true
    exec $0 $1 $2
  fi
  exit 1
elif [[ "$PKI_DONE" == *PKI:_VALID* ]]; then
  echo "PKI_DONE:_$PKI_DONE" && exit 0
else
  exit 0
fi
