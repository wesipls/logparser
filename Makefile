BINARY=logparser
PKG=./

# default version (can be overridden)
VERSION?=0.2

LDFLAGS=-ldflags "-X main.version=$(VERSION)"

build:
	go build $(LDFLAGS) -o $(BINARY) $(PKG)

linux:
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY)-linux-amd64 $(PKG)

darwin:
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY)-darwin-amd64 $(PKG)

darwin-arm:
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BINARY)-darwin-arm64 $(PKG)

all: linux darwin darwin-arm

test:
	cd tests && ./run.sh

clean:
	rm -f $(BINARY) $(BINARY)-*
