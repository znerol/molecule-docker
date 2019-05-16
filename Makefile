define FROM_default
    ifeq ($(FROM),)
        FROM := $(strip $(subst ., ,$(suffix $(subst :,.,$1))))
    endif
endef

Dockerfile.j2.raw:
	curl -o Dockerfile.j2.raw 'https://raw.githubusercontent.com/ansible/molecule/master/molecule/cookiecutter/scenario/driver/docker/%7B%7Bcookiecutter.molecule_directory%7D%7D/%7B%7Bcookiecutter.scenario_name%7D%7D/Dockerfile.j2'

Dockerfile.j2: Dockerfile.j2.raw
	j2 -o Dockerfile.j2 Dockerfile.j2.raw

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
	docker run -it --rm $(@:test/%=%) /bin/true

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
	rm -f Dockerfile.j2.raw Dockerfile.j2

.PHONY: clean distclean
