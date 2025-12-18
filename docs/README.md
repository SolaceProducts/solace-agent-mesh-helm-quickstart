# Solace Agent Mesh Documentation Site

This directory contains the Docusaurus-based documentation site for Solace Agent Mesh (SAM) Helm Chart.

## Local Development

To run the documentation site locally:

```bash
npm ci
npm start
```

This will start a development server at `http://localhost:3000`.

## Building the Site

To build the static site:

```bash
npm run build
```

The output will be in the `build/` directory.

## Project Structure

- `docs/` - Documentation markdown files
  - `intro.md` - Getting started guide
  - `network-configuration.md` - Network configuration guide
  - `persistence.md` - Persistence configuration guide
  - `agent-standalone-deployment.md` - Agent standalone deployment guide
  - `troubleshooting.md` - Troubleshooting guide
- `src/` - React components and custom pages
- `static/` - Static assets (images, files, etc.)
- `docusaurus.config.ts` - Docusaurus configuration
- `sidebars.ts` - Sidebar navigation configuration

## Deployment

The documentation is automatically deployed to GitHub Pages via the `.github/workflows/publish.yaml` workflow when a new tag is pushed. The site is published to:

**https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/docs/**

The main repository page redirects to the documentation site.

## Configuration

The site is configured for GitHub Pages deployment with:
- **Organization**: SolaceProducts
- **Project**: solace-agent-mesh-helm-quickstart
- **Base URL**: `/solace-agent-mesh-helm-quickstart/`

## Adding Documentation

1. Create a new markdown file in the `docs/` directory
2. Add frontmatter with `sidebar_position` and `title`:
   ```markdown
   ---
   sidebar_position: 4
   title: My New Doc
   ---

   # Content here
   ```
3. The file will automatically appear in the sidebar navigation

## Links

- **Documentation Site**: https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/docs/
- **GitHub Repository**: https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart
- **Helm Repository**: https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/
