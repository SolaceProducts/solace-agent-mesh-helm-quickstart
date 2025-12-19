import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Sidebar configuration for Solace Agent Mesh documentation.
 */
const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    {
      type: 'doc',
      id: 'intro',
      label: 'Getting Started',
    },
    {
      type: 'doc',
      id: 'network-configuration',
      label: 'Network Configuration',
    },
    {
      type: 'doc',
      id: 'persistence',
      label: 'Persistence Configuration',
    },
    {
      type: 'doc',
      id: 'standalone-agent-deployment',
      label: 'Standalone Agent Deployment',
    },
    {
      type: 'doc',
      id: 'troubleshooting',
      label: 'Troubleshooting',
    },
  ],
};

export default sidebars;
