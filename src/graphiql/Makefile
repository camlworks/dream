.PHONY : build
build :
	npm run build

.PHONY : install
install :
	npm ci

.PHONY : update
update :
	rm -rf node_modules package-lock.json
	npm install
	npm run build
