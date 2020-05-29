FROM jviottidc/windows-nodejs:12

COPY clone ./versioned-source

WORKDIR versioned-source

# Env vars injected by docker build
ARG ANALYTICS_MIXPANEL_TOKEN
ARG CSC_KEY_PASSWORD
ARG CSC_LINK

# Dependencies
RUN pip install --requirement requirements.txt
RUN make electron-develop

# Release
RUN make electron-build

RUN dir dist
