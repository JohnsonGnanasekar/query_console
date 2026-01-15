// Entry point for the QueryConsole Stimulus application
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "@hotwired/stimulus-loading"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Register all controllers in the controllers/query_console directory
import CollapsibleController from "./controllers/collapsible_controller"
import HistoryController from "./controllers/history_controller"
import EditorController from "./controllers/editor_controller"

application.register("collapsible", CollapsibleController)
application.register("history", HistoryController)
application.register("editor", EditorController)

export { application }
