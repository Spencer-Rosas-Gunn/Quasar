help:
	@echo "Usage:"
	@echo "    make help - print this message and exit"
	@echo "    make run ARCH=... - run the OS with the specified architecture"
	@echo "    make debug ARCH=... - debug the OS with the specified architecture"
	@echo "    make main ARCH=... - compile the OS without running"
	@echo "HINT: try \"ls arch\" to view available architectures\n"

run: main
	@bash arch/$(ARCH)/run.sh

debug: main
	@bash arch/$(ARCH)/debug.sh

main: src/ arch/
	@rm -f src/arch
	@ln -s ../arch/$(ARCH)/src src/arch
	@bash arch/$(ARCH)/build.sh
	@rm main.efi.obj main.pdb

clean:
	@rm -f main
	@rm -f src/arch
