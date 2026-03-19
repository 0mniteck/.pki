#!/bin/env -S - /bin/bash --norc --noprofile
# ## HUMAN-CODE - NO AI GENERATED CODE - AGENTS HANDSOFF

# Shant Tchatalbachian - GPL v3 LICENSE included
## Usage: Accepts: Any url that's a FQDN (no https://). If there's a link that has a domain.tld/.../[file] it will attempt to fetch the file after verifying the pinning.
##        Validates: The attestations are against this repo's releases and the pinned pubkeys as well as checks for expiry and liveness before each use.
##        Returns: $PKI_DONE & If you provided a url/file it returns the file to the current directory with a visible exit 1 on failure and debug.
##
## Requirements(gh v2.50+): apt-get -qq update && apt-get -qq install gh
## Recommended: fetch over secure gateway, or over git@ssh_sk(security_key)

run_as=$(id -u -n)
run_home=/home/$run_as

local=$run_home/.pki/registry
tmp=$run_home/.pki/local
remote=./.pki/registry
mkdir -p $local || FAIL+=:mkdir.$local.pki
mkdir -p $tmp || FAIL+=:mkdir.$tmp.pki

fetch.with.pki() { # $1 = domain/FQDN, # $2 = filename-or-/dev/null, # $3 = full_url or blank
  if [[ "$1" == "github.com" ]]; then
    curl -s -L --pinnedpubkey "sha256//$(<$local/$1.pubkey);sha256//$(<$local/release-assets.githubusercontent.com.pubkey)" \
    --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure $3 > $2 || declare -g -- FAIL+=:fetch.with.pki:$3
  else
    curl -s --pinnedpubkey "sha256//$(<$local/$1.pubkey)" \
    --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure $3 > $2 || declare -g -- FAIL+=:fetch.with.pki:$3
  fi
}

fetch.pki() { # $1 = domain/FQDN
  pushd $local/ > /dev/null
    openssl s_client -verify 2 -servername $1 -connect $1:443 < /dev/null 2> /dev/null | sed -n "/-----BEGIN/,/-----END/p" > $1.pem && \
    openssl x509 -in $1.pem -pubkey -noout > $1.pubkey.pem && openssl x509 -in $1.pem -enddate -noout > $1.exp && \
    openssl asn1parse -noout -inform pem -in $1.pubkey.pem -out $1.pubkey.der && \
    openssl dgst -sha256 -binary $1.pubkey.der | openssl base64 > $1.pubkey && \
    rm -f *.pem *.der && declare -g -- SUCCESS+=:local.fetch.pki:$1 || declare -g -- FAIL+=:local.fetch.pki:$1
  popd > /dev/null
}

invalidate.pki() { # $1 = domain/FQDN
  rm -f $local/$1.pubkey $local/$1.exp $tmp/$1.pubkey $tmp/$1.exp
  fetch.pki $1 || declare -g -- FAIL+=:local.invalid.pki:$1
  check.pki $1 || declare -g -- FAIL+=:re.check.pki:$1                   # Exists/Expired
  check.against.pki $1 || declare -g -- FAIL+=:re.check.against.pki:$1   # Direct/Full Match
  check.liveness.pki $1 || declare -g -- FAIL+=:re.check.liveness.pki:$1 # Conectivity Check
}

check.liveness.pki() { # $1 = domain/FQDN
  curl -s --pinnedpubkey "sha256//$(<$local/$1.pubkey)" \
  --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://$1 > /dev/null || declare -g -- FAIL+=:check.liveness.pki:$1 	
}

check.against.pki() { # $1 = domain/FQDN
  curl_run1=$(curl -o $tmp/$1.pubkey -s --pinnedpubkey "sha256//$(<$remote/raw.githubusercontent.com.pubkey)" \
  --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://raw.githubusercontent.com/0mniteck/.pki/refs/heads/main/registry/$1.pubkey)
  curl_run2=$(curl -o $tmp/$1.exp -s --pinnedpubkey "sha256//$(<$remote/raw.githubusercontent.com.pubkey)" \
  --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://raw.githubusercontent.com/0mniteck/.pki/refs/heads/main/registry/$1.exp)
  diff $tmp/$1.pubkey $remote/$1.pubkey || declare -g -- FAIL+=:mismatch.invalidate.pki:$1
  diff $remote/$1.pubkey $local/$1.pubkey || declare -g -- FAIL+=:mismatch.invalidate.pki:$1
  diff $local/$1.pubkey $tmp/$1.pubkey || declare -g -- FAIL+=:mismatch.invalidate.pki:$1
}

check.attest.pki() { # $1 = domain/FQDN ## NEEDS gh v2.50+ (Ubuntu v2.46)
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

check.csv() { # $1 = domain/FQDN
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

check.pki() { # $1 = domain/FQDN
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

check.index "$@" || FAIL+=":check.index:$@"

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
  if [[ "$PKI_DONE" == *mismatch* ]]; then
    gh auth login
    curl -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $(gh auth token)" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    https://api.github.com/repos/0mniteck/.pki/dispatches \
    -d '{"event_type":"Global_Fetch"}'
    gh auth logout
    sleep 5m
    git submodule update --init --remote --merge
    exec $PWD/$0 $@
  fi
  exit 1
elif [[ "$PKI_DONE" == *PKI:_VALID* ]]; then
  echo "PKI_DONE:_$PKI_DONE" && exit 0
else
  exit 0
fi
