# .pki

`.github/workflows` for attesting and pinning widely used public keys for mutual auth in https curl requests
(as a stop gap measure, only after an ssh connection has been established)

Add it to other projects as a submodule. Github workflows will update, validate, and attest to this repo
with know domains and their expiries adding into the `registry/` from the list stored in `index.csv`
## 

#### fetch and validate index registry + attest with sigstore + release immutably

#### [Github Workflow](https://github.com/0mniteck/.pki/blob/main/.github/workflows/action.yml) - <sub><sub>[![Check Attestation](https://github.com/0mniteck/.pki/actions/workflows/check-attest.yml/badge.svg)](https://github.com/0mniteck/.pki/actions/workflows/action.yml)</sub></sub>

> #### Attestation Created - v0.0.23 Immutable Tag
> - [https://github.com/0mniteck/.pki/attestations/20341720](https://github.com/0mniteck/.pki/attestations/20341720)
##

#### client side validation of `registry/` against expiry, liveness, and remote/ref
> [local.sh](https://github.com/0mniteck/.pki/blob/main/local.sh) # WIP - gh attestation verify (Ubuntu v2.46) - (Needs v2.50+) - skipping for now...

#### add function for local.sh to run at the project level script
```
validate.with.pki() { # \$1 = full_url.TDL/.../[file]
    chmod +x .pki/local.sh
    .pki/local.sh \$1 || exit 1
}
```

#### **for example fetch `secretservice` bin file after verifying pki is valid**
```
if [[ \"\$SKIP_LOGIN\" == \"\" ]]; then
  mkdir -p $docker_data/.docker && mkdir -p $home/$snap_path/.docker && wait 
  if [[ \"\$(which docker-credential-secretservice)\" == \"\" ]]; then
    validate.with.pki \"\$cred_helper\" || exit 1
    echo \"\$cred_helper_sha  \$cred_helper_name\" | sha512sum -c || exit 1
    mkdir -p $home/bin && mv $cred_helper_name $home/bin/docker-credential-secretservice
  fi

  echo '{
  \"credsStore\": \"secretservice\"
}' > $home/$snap_path/.docker/config.json

fi
```

#### add .pki to `.ssh/config` hosts
```
if [[ \"\$ssh_conf\" != *.pki* ]]; then
  echo \"
Host .pki
  Hostname github.com
  IdentityFile $home/\$PKI_ID_FILE
  IdentitiesOnly yes\" >> $home/.ssh/config
fi
```

### add read only ssh keys to the `deploy keys` ecdsa_sk/RSA_4096 (attended/unattended)
#### add ssh keys for `git@.pki:0mniteck/.pki.git` to each projects **`.identity`** file
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

#### lastly add submodule to `.gitmodules` of each project and `git submodule add git@.pki:0mniteck/.pki.git`
```
[submodule ".pki"]
	path = .pki
	url = git@.pki:0mniteck/.pki.git
	branch = main
```
