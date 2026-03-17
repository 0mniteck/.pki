# .pki

`.github/workflows` for attesting and pinning widely used public keys for mutual auth in https curl requests
(as a stop gap measure, only after an ssh connection has been established)

Add it to other projects as a submodule. Github workflows will update, validate, and attest to this repo
with know domains and their expiries adding into the `registry/` from the list stored in `index.csv` every 6 hours.
## 

#### fetch and validate index registry + attest with sigstore + release immutably

#### [Github Workflow](https://github.com/0mniteck/.pki/blob/main/.github/workflows/action.yml) - <sub><sub>[![Release](https://github.com/0mniteck/.pki/actions/workflows/action.yml/badge.svg)](https://github.com/0mniteck/.pki/actions/workflows/action.yml)</sub></sub>

> #### Attestation Created - v0.0.65 Immutable Tag
> - [https://github.com/0mniteck/.pki/attestations/21531877](https://github.com/0mniteck/.pki/attestations/21531877)
##

#### client side validation of `registry/` against expiry, liveness, and remote/ref
> [local.sh](https://github.com/0mniteck/.pki/blob/main/local.sh) # WIP - gh attestation verify (Ubuntu v2.46) - (Needs v2.50+) - skipping for now...

#### call function from local.sh to run validation in each project level script
```
validate.with.pki() { # $1 = full_url.TDL/.../[file] or blank to only verify
    chmod +x .pki/local.sh && ./.pki/local.sh $1 || exit 1
}
```

#### **for example fetch the `docker-credential-pass` bin file only after verifying all pubkey's are valid**
```
cred_helper=github.com/docker/docker-credential-helpers/releases/download/v0.9.5/docker-credential-pass-v0.9.5.linux-arm64
  if [[ "$(which docker-credential-pass)" == "" ]]; then
    validate.with.pki "$cred_helper" || exit 1
    echo "$cred_helper_sha  $cred_helper_name" | sha512sum -c || exit 1
    mkdir -p $HOME/bin && mv $cred_helper_name $HOME/bin/docker-credential-pass || exit 1
  fi
```

#### add .pki to `.ssh/config` hosts
```
if [[ "$ssh_conf" != *.pki* ]]; then
  echo "
Host .pki
  Hostname github.com
  IdentityFile $HOME/\$PKI_ID_FILE
  IdentitiesOnly yes" >> $HOME/.ssh/config
fi
```

### add read only ssh keys to the `deploy keys` ecdsa_sk/RSA_4096 (attended/unattended)
#### add ssh keys for `git@.pki:0mniteck/.pki.git` to each projects **`.identity`** file
```
# TODO: Generate repo keys r/o for public use

cat > $HOME/$PKI_ID_FILE << EOF_
-----BEGIN OPENSSH PRIVATE KEY-----
SSH PRIVATE KEY GOES HERE
-----END OPENSSH PRIVATE KEY-----
EOF_
cat > $HOME/$PKI_ID_FILE.pub << EOF__
SSH PUBKEY GOES HERE
EOF__
```

#### lastly add submodule to `.gitmodules` of each project and run `git submodule add git@.pki:0mniteck/.pki.git`
```
[submodule ".pki"]
	path = .pki
	url = git@.pki:0mniteck/.pki.git
	branch = main
```
