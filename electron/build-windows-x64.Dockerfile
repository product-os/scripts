FROM jviottidc/windows-nodejs:12

COPY clone ./versioned-source

WORKDIR versioned-source

# Dependencies
RUN pip install --requirement requirements.txt
RUN make electron-develop

# Lint
RUN make lint

# Tests
RUN make test-sdk
RUN make test-gui
RUN make test-spectron
