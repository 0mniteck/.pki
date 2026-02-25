#!/usr/bin/env -S - bash --norc --noprofile
# WIP - SLA 1 day
## Usage: Accepts: Any url thats a FQDN; If the link was a domain.tld/file it will attempt to fetch it otherwise,
##        Validates: The attestations against the pki and pinned pubkeys as well as checks expiry before each use.
##        Returns: If provided a url/file it returns a file to the current directory visible exit 1 on failure
## 
## Requirements: apt-get -qq update && apt-get -qq install gh
## Recommended: fetch over secure gateway, or over git@ssh_sk(security_key)

local=$HOME/.pki/registry
remote=./registry
mkdir -p $local

fetch.pki() { # $1 = domain/FQDN
pushd $local/ > /dev/null
  openssl s_client -servername $1 -connect $1:443 < /dev/null | sed -n "/-----BEGIN/,/-----END/p" > $1.pem && \
  openssl x509 -in $1.pem -pubkey -noout > $1.pubkey.pem && openssl x509 -in $1.pem -enddate -noout > $1.exp && \
  openssl asn1parse -noout -inform pem -in $1.pubkey.pem -out $1.pubkey.der && \
  openssl dgst -sha256 -binary $1.pubkey.der | openssl base64 > $1.pubkey && \
  rm -f *.pem *.der || exit 1
  echo "Successfully fetched pubkey for $1"
popd > /dev/null
}

validate.with.pki() { # $1 = domain/FQDN, # $2 = filename-or-/dev/null, # $3 = full_url or blank
  attest.with.gh() {
	pushd $remote/ > /dev/null
    gh attestation verify $1 --repo 0mniteck/.pki || trturn 1;
    echo "$1.pubkey Attested"
  }
  fetch.with.pki() {
    curl -s --pinnedpubkey "sha256//$(<$remote/$1.pubkey)" \
    --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://\$3 > \$2 || exit 1
  }
  check.remote.pki() { # $1 = domain/FQDN
  chk_rmt=$(curl -o $local/$1.pubkey -s --pinnedpubkey "sha256//1FtgkXeU53bUTaObUogizKNIqs/ZGaEo1k2AwG30xts=" \
  --tlsv1.3 --from.proto -all,+https --remove-on-error --no-insecure https://raw.githubusercontent.com/0mniteck/.pki/refs/heads/main/registry/$1.pubkey)
  chk_rmt
  }
  attest.with.gh $1 || exit 1
  curl -s --pinnedpubkey \"sha256//$(<.pki/registry/$1.pubkey)" \
  --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://$1 > /dev/null || exit 1
  
  popd > /dev/null
  fetch.with.pki $1 $2 $3 || exit 1
  echo "$1.pubkey is valid, fetched $2."
}

invalidate.pki() { # $1 = domain/FQDN
  rm -f $local/$1.pubkey $local/$1.exp
  fetch.pki $1 || check.index && check.index
}

validate.pki() { # $1 = domain/FQDN
  pushd $local/ > /dev/null
    gh attestation verify $1 --repo 0mniteck/.pki || invalidate $I;
    echo \"$1.pubkey Attested\"
  done;
  popd > /dev/null
}

check.csv() { # $1 = domain/FQDN
  dater=$(date -d "$(cat $remote/$1.exp | cut -d'=' -f2)" +%s)
  date=$(date +%s)
  if [[ "$dater" -le "$date" ]]; then
    fetch.pki $1
  fi
  
}

check.against.csv() { # $1 = domain/FQDN
  dater=$(date -d "$(cat local/$1.exp | cut -d'=' -f2)" +%s)
  date=$(date +%s)
  if [[ "$dater" -le "$date" ]]; then
    fetch.pki $1
  fi
  check.against.pki $1
}

check.liveness.csv() { # $1 = domain/FQDN
  dater=$(date -d "$(cat local/$1.exp | cut -d'=' -f2)" +%s)
  date=$(date +%s)
  if [[ "$dater" -le "$date" ]]; then
    fetch.pki $1
  fi
  check.remote.pki $1
}

check.against.pki() { # $1 = domain/FQDN
  if [[ -f "registry/$1.pubkey" ]]; then
    check.against.csv $1
  else
    invalidate.pki $1
  fi
}

check.pki() { # $1 = domain/FQDN
  if [[ -f "registry/$1.pubkey" ]]; then
    check.csv $1
  else
    fetch.pki $1
  fi
}

check.index() {
  for i in $(cat index.csv | tr ',' '\n' | cat); do
    check.pki $i
  done
}

check.liveness() {
  for i in $(cat index.csv | tr ',' '\n' | cat); do
    check.liveness.pki $i
  done
}

check.against.index() {
  for i in $(cat index.csv | tr ',' '\n' | cat); do
    check.against.pki $i
  done
}

check.index
check.liveness
check.against.index

echo DONE
