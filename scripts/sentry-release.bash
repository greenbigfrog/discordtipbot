#!/bin/bash
if [ $TRAVIS_BRANCH == "master" ]; then
    curl -sL https://sentry.io/get-cli/ | bash;
    VERSION=$(sentry-cli releases propose-version);
    sentry-cli releases new -p discordtipbot $VERSION;
    sentry-cli releases set-commits --auto $VERSION;
    sentry-cli releases deploys $VERSION new --env Travis;
fi