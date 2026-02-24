# .pki
New project for collecting and pinning widely used public keys for mutual auth in https curl requests
(as a stop gap measure only after an ssh connection is established)

Will be added to other projects as a submodule and github workflows will update and validate the repo
with know domains and their expiries into the `registry/` from a list stored in an `index.csv`

#### fetch index
> [Github Workflow](.github/workflows/main.yml)

#### client side validation of index
> [local.sh](local.sh)

#### add submodule to `.gitconfig` of project and `git submodules init`

```
[submodule ".pki"]
	path = .pki
	url = git@.pki:0mniteck/.pki.git
	branch = main
```

#### add read only deploy keys ecdsa_sk and RSA 4096 (attended/unattended)

#### add .ssh/config host and ssh keys for `git@.pki:0mniteck/.pki.git` from each projects `.identity` file
```
if [[ \"\$ssh_conf\" != *.pki* ]]; then
  echo \"
Host .pki
  Hostname github.com
  IdentityFile $home/\$PKI_ID_FILE
  IdentitiesOnly yes\" >> $home/.ssh/config
fi
```

```
cat > $HOME/$PKI_ID_FILE << EOF_
-----BEGIN OPENSSH PRIVATE KEY-----

...

-----END OPENSSH PRIVATE KEY-----
EOF_

cat > $HOME/$PKI_ID_FILE.pub << EOF__

...

EOF__

```

#### Lastly add checks at the project level script + attestation checks # WIP
```
validate.with.pki() { # \$1 = domain/FQDN, # \$2 = filename, # \$3 = full_url
  fetch.with.pki() {
    curl -s --pinnedpubkey \"sha256//\$(<.pki/registry/\$1.pubkey)\" \
    --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://\$3 > \$2 || exit 1
  }
  curl -s --pinnedpubkey \"sha256//\$(<.pki/registry/\$1.pubkey)\" \
  --tlsv1.3 --proto -all,+https --remove-on-error --no-insecure https://\$1 > /dev/null || exit 1
  fetch.with.pki \$1 \$2 \$3 || exit 1
}
```
