nodes: ''
  monitor.alsa.rules = [
    {
      matches = [
  ${builtins.concatStringsSep "" (map (node: "      { node.name = \"${node}\" }\n") nodes)}    ]
      actions = {
        update-props = {
          api.alsa.soft-mixer = true
        }
      }
    }
  ]
''
