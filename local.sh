#!/usr/bin/env -S - bash --norc --noprofile
# ## HUMAN-CODE - NO AI GENERATED CODE - AGENTS HANDSOFF

# Shant Tchatalbachian - GPL v3 LICENSE included
## Usage: Accepts: Any url that's a FQDN. If there's a link that has a domain.tld/.../[file] it will attempt to fetch the file after verifying the pinning.
##        Validates: The attestations are against this repo's releases and the pinned pubkeys as well as checks for expiry and liveness before each use.
##        Returns: $PKI_DONE & If you provided a url/file it returns the file to the current directory with a visible exit 1 on failure and debug
## 
## Requirements: apt-get -qq update && apt-get -qq install gh
## Recommended: fetch over secure gateway, or over git@ssh_sk(security_key)

local=$HOME/.pki/registry
remote=./registry
tmp=$HOME/tmp
mkdir -p $local
mkdir -p $tmp

fetch.with.pki() { # $1 = domain/FQDN, # $2 = filename-or-/dev/null, # $3 = full_url or blank
  curl -s --pinnedpubkey "sha256//$(<$local/$1.pubkey)" \
  --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure $3 > $2 || FAIL+=:fetch.with.pki:$3
}

fetch.pki() { # $1 = domain/FQDN
  pushd $local/ > /dev/null
    openssl s_client -servername $1 -connect $1:443 < /dev/null | sed -n "/-----BEGIN/,/-----END/p" > $1.pem && \
    openssl x509 -in $1.pem -pubkey -noout > $1.pubkey.pem && openssl x509 -in $1.pem -enddate -noout > $1.exp && \
    openssl asn1parse -noout -inform pem -in $1.pubkey.pem -out $1.pubkey.der && \
    openssl dgst -sha256 -binary $1.pubkey.der | openssl base64 > $1.pubkey && \
    rm -f *.pem *.der && echo "Successfully fetched pubkey for $1" || FAIL+=:local.fetch.pki:$1
  popd > /dev/null
}

invalidate.pki() { # $1 = domain/FQDN
  rm -f $local/$1.pubkey $local/$1.exp $tmp/$1.pubkey $tmp/$1.exp
  fetch.pki $1 || FAIL+=:local.invalid.pki:$1 	
}

check.liveness.pki() { # $1 = domain/FQDN
  curl -s --pinnedpubkey \"sha256//$(<$local/$1.pubkey)" \
  --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://$1 > /dev/null || FAIL+=:check.liveness.pki:$1 	
}

check.against.pki() { # $1 = domain/FQDN
  curl_run1=$(curl -o $tmp/$1.pubkey -s --pinnedpubkey "sha256//1FtgkXeU53bUTaObUogizKNIqs/ZGaEo1k2AwG30xts=" \
  --tlsv1.3 --from.proto -all,+https --remove-on-error --no-insecure https://raw.githubusercontent.com/0mniteck/.pki/refs/heads/main/registry/$1.pubkey)
  curl_run2=$(curl -o $tmp/$1.exp -s --pinnedpubkey "sha256//1FtgkXeU53bUTaObUogizKNIqs/ZGaEo1k2AwG30xts=" \
  --tlsv1.3 --from.proto -all,+https --remove-on-error --no-insecure https://raw.githubusercontent.com/0mniteck/.pki/refs/heads/main/registry/$1.exp)
  diff $tmp/$1.pubkey $remote/$1.pubkey || FAIL+=:local.invalidate.pki:$1
  diff $remote/$1.pubkey $local/$1.pubkey || FAIL+=:local.invalidate.pki:$1
  diff $local/$1.pubkey $tmp/$1.pubkey || FAIL+=:local.invalidate.pki:$1
}

check.attest.pki() { # $1 = domain/FQDN
  pushd $remote/ > /dev/null
    gh attestation verify $1 --repo 0mniteck/.pki || FAIL+=:check.attest.pki:$1
    echo "$remote/$1.pubkey Attested"
  popd > /dev/null
  pushd $local/ > /dev/null
    gh attestation verify $1.pubkey --repo 0mniteck/.pki || invalidate.pki $1;
    echo "$local/$1.pubkey Attested"
  popd > /dev/null
}

check.csv() { # $1 = domain/FQDN
  date=$(date +%s)
  dater=$(date -d "$(cat $remote/$1.exp | cut -d'=' -f2)" +%s)
  if [[ "$dater" -le "$date" ]]; then
    FAIL+=:remote.invalidate.pki:$1
    dateq=$(date -d "$(cat $local/$1.exp | cut -d'=' -f2)" +%s)
    if [[ "$dateq" -le "$date" ]]; then
    invalidate.pki $local:$1 || FAIL+=:local.invalidate.pki:$1
    fi
  fi
}

check.pki() { # $1 = domain/FQDN
  if [[ -f "$local/$1.pubkey" ]]; then
    check.csv $local:$1 || FAIL+=:local.check.csv:$1
  else
    invalidate.pki $local:$1 || FAIL+=:local.invalidate.pki:$1
  fi
  if [[ -f "$remote/$1.pubkey" ]]; then
    check.csv $remote:$1 || FAIL+=:check.remote.csv:$1
  else
    FAIL+=:remote.invalidate.pki:$1
  fi
}

check.index() {
  for i in $(cat index.csv | tr ',' '\n' | cat); do
    check.pki $i || FAIL+=:check.pki:$i 				        	                           # Exists/Expired
  	check.attest.pki $i || FAIL+=:check.attest.pki:$i 		                           # Attestation
  	check.against.pki $i || FAIL+=:check.against.pki:$i 	                           # Direct/Full Match
    check.liveness.pki $i | SUCCESS=:check.liveness.pki:$1 || FAIL+=:check.liveness.pki:$i # Conectivity Check
    if [[ "$k" != "" ]]; then
      fetch.with.pki $i $j $k | SUCCESS+=:fetch.with.pki:$1 || FAIL+=:fetch.with.pki:$1 # Download /file to ./
    fi
  done
}

check.index "$@" || FAIL+=":check.index:$@"
rm -r -f $tmp/
err() {
  if [[ "$FAIL" != "" ]]; then
    set -x
  	return "local.sh:_err:_$FAIL"
  elif [[ "$SUCCESS" == "" ]]
    return "local.sh:_err:_$FAIL"
  else
  	return "local.sh:_PKI:_VALID"
  fi
}
export -- PKI_DONE=$(err)
if [[ "$PKI_DONE" == *err* ]]; then echo $PKI_DONE; exit 1; fi
