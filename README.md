# .pki
New project for collecting and pinning widely used public keys for mutual auth in https curl requests as a stop gap measure

Will be added to other projects as a submodule and github workflows will update the `registry/` folder
with know domains and their expiries from a list stored in an `index.csv`

#### fetch index
> [Github Workflow](.github/workflows/main.yml)

#### client side checks
> [local.sh](local.sh)

#### add submodule to `.gitconfig` of project and `git submodules init`

```
[submodule ".pki"]
	path = .pki
	url = git@.pki:0mniteck/.pki.git
	branch = main
```

#### add read only deploy key ecdsa_sk and RSA 4096 (attended/unattended)

#### add .ssh/config host and ssh keys for `git@.pki:0mniteck/.pki.git` from each projects `.identity` file
```
if [[ \"\$ssh_conf\" != *.pki* ]]; then
  echo \"
Host .pki
  Hostname github.com
  IdentityFile $home/\$IDENTITY_FILE
  IdentitiesOnly yes\" >> $home/.ssh/config
fi
```

```
cat > $HOME/$IDENTITY_FILE << EOF_
-----BEGIN OPENSSH PRIVATE KEY-----

...

-----END OPENSSH PRIVATE KEY-----
EOF_

cat > $HOME/$IDENTITY_FILE.pub << EOF__

...

EOF__

```
