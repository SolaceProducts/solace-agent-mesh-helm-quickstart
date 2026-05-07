config.yaml: |
  # Sample configuration file
  app:
    name: {{ .Chart.Name }}
    version: {{ .Chart.Version }}

  settings:
    debug: false
    logLevel: "info"
