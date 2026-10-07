DIR = testdir
MAL_DIR = quarantine
INTERVAL = 5

.PHONY: all prebuild run restore

all: run

prebuild:
	mkdir -p $(MAL_DIR)

run: prebuild
	./antivirusd.sh $(DIR) $(MAL_DIR) $(INTERVAL)

restore: prebuild
	./restore.sh $(DIR) $(MAL_DIR)
