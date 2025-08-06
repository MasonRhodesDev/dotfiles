import app from "ags/gtk4/app"
import style from "./style.scss"
import Bar from "./widget/Bar"
import { Astal } from "ags/gtk4"

function NotifyWindow(monitor: 0) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window >
    jaskldfljasdl
    </window>
  )
}

app.start({
  css: style,
  main() {
    NotifyWindow(0)
  },
})
