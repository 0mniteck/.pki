#!/usr/bin/env -S - bash --norc --noprofile

# WIP

fetch.pki() { # $1 = domain/FQDN
mkdir -p local
pushd local
  openssl s_client -servername $1 -connect $1:443 < /dev/null | sed -n "/-----BEGIN/,/-----END/p" > $1.pem && \
  openssl x509 -in $1.pem -pubkey -noout > $1.pubkey.pem && openssl x509 -in $1.pem -enddate -noout > $1.exp && \
  openssl asn1parse -noout -inform pem -in $1.pubkey.pem -out $1.pubkey.der && \
  openssl dgst -sha256 -binary $1.pubkey.der | openssl base64 > $1.pubkey && \
  rm -f *.pem *.der || exit 1
  echo "Successfully fetched pubkey for $1"
popd
}

check.remote.pki() { # $1 = domain/FQDN
  curl -o test/$1.pubkey -s --pinnedpubkey "sha256//1FtgkXeU53bUTaObUogizKNIqs/ZGaEo1k2AwG30xts=" \
--tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://raw.githubusercontent.com/0mniteck/.pki/refs/heads/main/registry/$1.pubkey
}

check.csv() { # $1 = domain/FQDN
  dater=$(date -d "$(cat registry/$1.exp | cut -d'=' -f2)" +%s)
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

invalidate.pki() {
  rm -f local/$1.pubkey.valid test/$1.pubkey
  cp local/$1.pubkey local/$1.pubkey.invalid
}

validate.pki() {
  if [[ ]]; then
  
  rm -f local/$1.pubkey local/$1.pubkey.invalid
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
