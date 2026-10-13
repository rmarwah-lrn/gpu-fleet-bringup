SHELL := /bin/sh
DOMAIN_URI ?= qemu:///session
SUSHY_PORT ?= 8000
VBMC_PORT_0 ?= 6230
VBMC_PORT_1 ?= 6231

.PHONY: check mockup-start mockup-walk vms-create sushy-start sushy-walk sushy-actions vbmc-daemon vbmc-start ipmi-actions clean

check:
	./scripts/check-prereqs.sh

mockup-start:
	docker compose up --build

mockup-walk:
	./scripts/redfish-walk.sh http://127.0.0.1:8000

vms-create:
	DOMAIN_URI=$(DOMAIN_URI) ./scripts/create-libvirt-vms.sh

sushy-start:
	sushy-emulator --port $(SUSHY_PORT) --libvirt-uri $(DOMAIN_URI)

sushy-walk:
	./scripts/redfish-walk.sh http://127.0.0.1:$(SUSHY_PORT)

sushy-actions:
	./scripts/redfish-actions.sh http://127.0.0.1:$(SUSHY_PORT)

vbmc-start:
	vbmc add redfish-lab-node0 --port $(VBMC_PORT_0) --libvirt-uri $(DOMAIN_URI) && \
	 vbmc add redfish-lab-node1 --port $(VBMC_PORT_1) --libvirt-uri $(DOMAIN_URI) && \
	 vbmc start redfish-lab-node0 && vbmc start redfish-lab-node1 && vbmc list

vbmc-daemon:
	vbmcd

ipmi-actions:
	VBMC_PORT_0=$(VBMC_PORT_0) ./scripts/ipmi-actions.sh

clean:
	- vbmc stop redfish-lab-node0 redfish-lab-node1
	- vbmc delete redfish-lab-node0 redfish-lab-node1
	- virsh -c $(DOMAIN_URI) destroy redfish-lab-node0
	- virsh -c $(DOMAIN_URI) destroy redfish-lab-node1
	- virsh -c $(DOMAIN_URI) undefine redfish-lab-node0 --nvram --remove-all-storage
	- virsh -c $(DOMAIN_URI) undefine redfish-lab-node1 --nvram --remove-all-storage
