Prebuilt images for ansible/molecule
====================================

This repository provides a `Makefile` which simplifies creation of pre-built
docker images for [ansible/molecule](https://github.com/ansible/molecule).

The `Makefile` provides an implicit rule with the prefix `image/` where the
suffix will be used as the tag name. E.g. `make image/myuser/myimage:debian`
will produce a docker image `myuser/myimage` with the tag `debian`.

The source repository is derived from the `tag` part of the target image. In
order to custamize the source image, specify the `FROM` parameter. E.g., `make
image/myuser/myimage:ubuntu-xenial FROM=ubuntu:xenial` will produce an image
from a specific source tag.
