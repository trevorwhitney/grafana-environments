.PHONY: gel-distributed

gel-distributed:
	make -C $(CURDIR)/clusters/gel-distributed up

loki-distributed:
	make -C $(CURDIR)/clusters/loki-distributed up

loki-simple-scalable:
	make -C $(CURDIR)/clusters/loki-simple-scalable up

down:
	make -C $(CURDIR)/clusters/gel-distributed down
	make -C $(CURDIR)/clusters/loki-distributed down
	make -C $(CURDIR)/clusters/loki-simple-scalable down
