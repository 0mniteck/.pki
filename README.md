# .pki
New project for collecting and pinning widely used public keys for mutual auth in https curl requests as a stop gap measure

Will be added to other projects as a submodule and github workflows will update the `registry/` folder
with know domains and their expiries from a list stored in an `index.csv`

#### fetch index
```
fetch.pki() { # $1 = domain/FQDN
pushd /registry
  openssl s_client -servername $1 -connect $1:443 < /dev/null | sed -n "/-----BEGIN/,/-----END/p" > $1.pem && \
  openssl x509 -in $1.pem -pubkey -noout > $1.pubkey.pem && openssl x509 -in $1.pem -enddate -noout > $1.exp &&\
  openssl asn1parse -noout -inform pem -in $1.pubkey.pem -out $1.pubkey.der && \
  openssl dgst -sha256 -binary $1.pubkey.der | openssl base64 > $1.pubkey && \
  rm -f *.pem *.der || exit 1
  echo "Successfully fetched pubkey for $1"
popd
}

check.csv() { # $1 = domain/FQDN
  dater=$(date -d "$(cat registry/$1.exp | cut -d'=' -f2)" +%s)
  date=$(date +%s)
  if [[ "$dater" -le "$date" ]]; then
    fetch.pki $1
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

```

#### client side checks
```
curl -o /tmp/warp.status -s --pinnedpubkey "sha256//$(<.pki/registry/www.cloudflare.com.pubkey)" \
--tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://www.cloudflare.com/cdn-cgi/trace | grep warp= || exit 1
```

#### add submodule to .gitconfig
```
[submodule ".pki"]
	path = .pki
	url = git@.pki:0mniteck/.pki.git
	branch = main
```

#### add each repo to deploy keys in this repo as read only
