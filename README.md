# PEPETUAL Millionaire — Public Launch Kit

Welcome to the public repository bundle for the PEPETUAL Millionaire ecosystem. This snapshot contains everything a community member, partner, or auditor needs to understand how the protocol works, verify the deployed contracts, and run the public dashboard locally.

## What's Inside

- `docs/` — plain-language guides covering the Overflow naming framework, protocol overview, and a public raise walkthrough.
- `contracts/` — verified mainnet addresses plus ABI files for the on-chain contracts.
- `assets/` — brand placeholders for explorers and social previews (replace with the final launch artwork before publishing).
- `.env.example` — required environment variables to run the public dapp against Ethereum mainnet.

## Public Dashboard Quickstart

The live public dashboard lives in a separate repository, but you can run it locally with the information in this kit:

```bash
# clone the production dashboard repo
git clone https://github.com/<org>/pepetual-dashboard.git
cd pepetual-dashboard

# install dependencies
npm install

# create your .env file using the values in this kit
cp ../public-repo/.env.example .env
# fill in WalletConnect (Reown) + RPC values

# start the dev server
npm run dev
```

The dashboard reads addresses and ABI information from the bundled JSON files. If you fork or redeploy contracts, update `contracts/addresses.mainnet.json` and re-run the app.

## How to Use This Bundle

1. **Educate** — Share the guides in `docs/` with community members so the Overflow vocabulary stays consistent across content.
2. **Verify** — Cross-check the contract addresses and ABIs when adding listings to explorers, DEX aggregators, or third-party tooling.
3. **Customize** — Drop final launch visuals into `assets/` (200×200 PNG/SVG recommended) before publishing the public repository.
4. **Extend** — Fork this folder into a dedicated public repo (e.g., `github.com/<org>/pepetual-public`) and keep it in sync with mainnet changes.

## Contributing

Issues and PRs are welcome once the public repo goes live. Keep submissions scoped to public materials—deployment scripts, privileged runbooks, and owner-only tooling remain in private ops repositories.

## License

Choose the license that matches your launch strategy (MIT, Apache-2.0, or custom). Include it alongside this README before publishing.
