import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Solace Agent Mesh',
  tagline: 'Helm Chart & Documentation',
  favicon: 'img/favicon.png',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://solaceproducts.github.io',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/solace-agent-mesh-helm-quickstart/docs/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'SolaceProducts', // Usually your GitHub org/user name.
  projectName: 'solace-agent-mesh-helm-quickstart', // Usually your repo name.

  onBrokenLinks: 'throw',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/', // Serve docs at the root
          sidebarPath: './sidebars.ts',
          editUrl:
            'https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/edit/main/',
        },
        blog: false, // Disable blog
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Solace Agent Mesh',
      logo: {
        alt: 'Solace Logo',
        src: 'img/logo.png',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Getting Started',
              to: '/',
            },
            {
              label: 'Network Configuration',
              to: '/network-configuration',
            },
            {
              label: 'Troubleshooting',
              to: '/troubleshooting',
            },
          ],
        },
        {
          title: 'Resources',
          items: [
            {
              label: 'Solace Docs',
              href: 'https://docs.solace.com/',
            },
            {
              label: 'GitHub Repository',
              href: 'https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart',
            },
          ],
        },
        {
          title: 'Helm Repository',
          items: [
            {
              label: 'Chart Index',
              href: 'https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/index.yaml',
            },
            {
              label: 'Report Issues',
              href: 'https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/issues',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Solace. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
