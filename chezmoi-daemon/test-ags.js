#!/usr/bin/env -S ags run --gtk 3

import { App } from "astal/gtk3"

function TestWindow() {
  return (
    <window class="TestWindow">
      <box>
        <label label="AGS Test Window" />
      </box>
    </window>
  )
}

App.start({
  main() {
    TestWindow()
  },
})