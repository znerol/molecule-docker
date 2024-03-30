define FROM_default
    ifeq ($(FROM),)
        FROM := $(strip $(subst ., ,$(suffix $(subst :,.,$1))))
    endif
endef

Dockerfile.j2:
	curl -f -o Dockerfile.j2 'https://raw.githubusercontent.com/ansible/molecule/stable/3.4/src/molecule/data/Dockerfile.j2'

image/%/data.yml: Dockerfile.j2
	mkdir -p $(@D)
	$(eval $(call FROM_default, $(@D)))
	echo "item: { image: '$(FROM)' }" > $@

image/%/Dockerfile: image/%/data.yml
	mkdir -p $(@D)
	j2 -o $@ Dockerfile.j2 $<

image/%: image/%/Dockerfile
	$(eval $(call FROM_default, $(@D)))
	podman pull $(FROM)
	podman build $(BUILD_ARGS) --tag=$(@:image/%=%) --file=$< .

test/%: image/%
	podman run --rm $(@:test/%=%) /bin/true

image-systemd/%/Dockerfile: image/%/data.yml
	mkdir -p $(@D)
	j2 -o $@ Dockerfile.j2 $<
	cat variants/systemd >> $@

image-systemd/%: image-systemd/%/Dockerfile
	$(eval $(call FROM_default, $(@D)))
	podman pull $(FROM)
	podman build $(BUILD_ARGS) --tag=$(@:image-systemd/%=%)-systemd --file=$< .

test-systemd/%: image-systemd/%
	$(eval _CONTAINER := $(shell podman run -d --systemd=always $(@:test-systemd/%=%)-systemd))
	podman exec $(_CONTAINER) /bin/true
	-podman stop $(_CONTAINER); podman logs $(_CONTAINER); podman rm $(_CONTAINER)

clean:
	rm -rf image image-systemd

distclean: clean
	rm -f Dockerfile.j2

.PHONY: clean distclean
