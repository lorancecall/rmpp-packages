# Forking: your own package repository

This repository can be forked to publish your own packages the same way. You need your own signing key, because
the private key of this repository is not public.

## Why the key name matters

Every package and the repository index (`APKINDEX.tar.gz`) are signed with one RSA key. The signature records the
key's file name, and apk on the Paper Pro looks for a public key with exactly that name in
`/home/root/.vellum/etc/apk/keys/`. So the name is part of every published package: if it changes, every Paper Pro
has to get the new public key (the installer and `install.sh` download it by name).

## Make a key

Pick a name (here `yourname-rmpp`):

```sh
NAME=yourname-rmpp
openssl genrsa -out keys/$NAME.rsa 4096
openssl rsa -in keys/$NAME.rsa -pubout -out keys/$NAME.rsa.pub
gh secret set SIGNING_KEY -R <owner>/rmpp-packages < keys/$NAME.rsa
```

`keys/*.rsa` is in `.gitignore`: commit only `keys/$NAME.rsa.pub`, delete the old `.pub`, and keep the private key
backed up offline. CI reads it from the Actions secret `SIGNING_KEY`.

Then replace the old name, the repository URL and the maintainer everywhere:

```sh
git grep -l lorancecall-rmpp
git grep -l lorancecall.github.io/rmpp-packages
git grep -l 'maintainer=' packages
```

## Build locally

`scripts/build-package.sh <package>` needs [vbuild](https://github.com/Eeems/vbuild) and the private key at
`keys/<name>.rsa`. It signs with the same key as CI.

## Changing the key later

The next push to `main` re-signs every package and the index. A Paper Pro that only have the old public key then fails
`vellum update` with an untrusted-signature error until it gets the new one: run the installer again, or on the
Paper Pro `wget -qO- https://<owner>.github.io/rmpp-packages/install.sh | sh`. Installed packages keep working in the
meantime. If the name changed, the old `.pub` can be deleted from `/home/root/.vellum/etc/apk/keys/`.

## Adding mods to the installer menu

See [MODS.md](../MODS.md).
