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
	docker build --tag=$(@:image/%=%) --file=$< .

clean:
	rm -rf image

distclean: clean
	rm -f Dockerfile.j2.raw Dockerfile.j2

.PHONY: clean distclean