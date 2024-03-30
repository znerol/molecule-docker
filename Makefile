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
	docker pull $(FROM)
	docker pull $(@:image/%=%) || true
	docker build $(BUILD_ARGS) --cache-from=$(@:image/%=%) --tag=$(@:image/%=%) --file=$< .

test/%: image/%
	docker run --rm $(@:test/%=%) /bin/true

image-systemd/%/Dockerfile: image/%/data.yml
	mkdir -p $(@D)
	j2 -o $@ Dockerfile.j2 $<
	cat variants/systemd >> $@

image-systemd/%: image-systemd/%/Dockerfile
	$(eval $(call FROM_default, $(@D)))
	docker pull $(FROM)
	docker pull $(@:image-systemd/%=%) || true
	docker pull $(@:image-systemd/%=%)-systemd || true
	docker build $(BUILD_ARGS) --cache-from=$(@:image-systemd/%=%) --cache-from=$(@:image-systemd/%=%)-systemd --tag=$(@:image-systemd/%=%)-systemd --file=$< .

test-systemd/%: image-systemd/%
	$(eval _CONTAINER := $(shell docker run -d -it --cap-add SYS_ADMIN --tmpfs /run --tmpfs /run/lock --volume /sys/fs/cgroup:/sys/fs/cgroup:ro $(@:test-systemd/%=%)-systemd))
	docker exec -it $(_CONTAINER) /bin/true
	-docker stop $(_CONTAINER); docker logs $(_CONTAINER); docker rm $(_CONTAINER)

clean:
	rm -rf image image-systemd

distclean: clean
	rm -f Dockerfile.j2

.PHONY: clean distclean
