# .pki
New project for collecting and pinning widely used public keys for mutual auth in https curl requests
(as a stop gap measure only after an ssh connection is established)

Adding it to other projects as a submodule. Github workflows will update, validate, and attest to this repo
with know domains and their expiries adding into the `registry/` from the list stored in an `index.csv`

#### fetch and validate index registry + attest with sigstore + immutable releases
> [Github Workflow](.github/workflows/check-attest.yml)

#### client side validation of `registry/` against expiry, attested pki, and liveness
> [local.sh](local.sh) # WIP - ETA 1 day SLA

#### add attestation and liveness checks at the project level script
```
validate.with.pki() { # \$1 = domain/FQDN, # \$2 = filename, # \$3 = full_url
  attest.with.gh() {
	pkexec bash -c \"apt-get -qq update && \
				 apt-get install gh\"
    echo \"Attesting \$1.pubkey\"
	pushd .pki/ > /dev/null
  for I in /registry/*; do
	  gh attestation verify $I --repo 0mniteck/.pki || exit 1;
    echo \"$1.pubkey Attested\"
  done;
  }
  fetch.with.pki() {
    curl -s --pinnedpubkey \"sha256//\$(<.pki/registry/\$1.pubkey)\" \
    --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://\$3 > \$2 || exit 1
  }
  attest.with.gh \$1 || exit 1
  popd > /dev/null
  curl -s --pinnedpubkey \"sha256//\$(<.pki/registry/\$1.pubkey)\" \
  --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://\$1 > /dev/null || exit 1
  fetch.with.pki \$1 \$2 \$3 || exit 1
  echo \"\$1.pubkey is valid, fetched \$2.\"
}
```

#### **for example fetch this file after verifying attestation is valid**
```
if [[ \"\$SKIP_LOGIN\" == \"\" ]]; then
  mkdir -p $docker_data/.docker && mkdir -p $home/$snap_path/.docker && wait 
  if [[ \"\$(which docker-credential-secretservice)\" == \"\" ]]; then
    validate.with.pki github.com \"\$cred_helper_name\" \"\$cred_helper\" || exit 1
    echo \"\$cred_helper_sha  \$cred_helper_name\" | sha512sum -c || exit 1
    mkdir -p $home/bin && mv $cred_helper_name $home/bin/docker-credential-secretservice
  fi
```

#### add .ssh/config host and ssh keys for `git@.pki:0mniteck/.pki.git` to each projects **`.identity`** file
```
if [[ \"\$ssh_conf\" != *.pki* ]]; then
  echo \"
Host .pki
  Hostname github.com
  IdentityFile $home/\$PKI_ID_FILE
  IdentitiesOnly yes\" >> $home/.ssh/config
fi
```

#### add read only deploy keys ecdsa_sk and RSA 4096 (attended/unattended)
```
cat > $HOME/$PKI_ID_FILE << EOF_
-----BEGIN OPENSSH PRIVATE KEY-----

YOUR KEY

-----END OPENSSH PRIVATE KEY-----
EOF_

cat > $HOME/$PKI_ID_FILE.pub << EOF__

YOUR PUBKEY

EOF__
```

#### Lastly add submodule to `.gitconfig` of project and `git submodules init`
```
[submodule ".pki"]
	path = .pki
	url = git@.pki:0mniteck/.pki.git
	branch = main
```
