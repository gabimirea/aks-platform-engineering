# [Backstage](https://backstage.io)

This is your newly scaffolded Backstage App, Good Luck!

To start the app, run:

```sh
yarn install
yarn start
```

To use GitHub-backed flows such as `Catalog Import -> Create PR`, configure these environment variables before starting Backstage:

```sh
AUTH_GITHUB_CLIENT_ID=...
AUTH_GITHUB_CLIENT_SECRET=...
GITHUB_TOKEN=...
```

The backend now exposes both `guest` and `github` auth providers. `guest` remains the default sign-in provider, while GitHub OAuth is used on demand by plugins that need GitHub access.
