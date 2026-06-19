BdiClient <- function(host = "127.0.0.1", port = 44444) {
  con <- socketConnection(host = host, port = port, blocking = TRUE, open = "r+")
  handlers <- list()

  sendPerception <- function(action, perception) {
    payload <- sprintf('{"type":"perception","action":"%s","perception":"%s"}\n', action, perception)
    writeLines(payload, con)
  }

  sendActionResult <- function(actionId, success) {
    success_str <- if (success) "true" else "false"
    payload <- sprintf('{"type":"action_result","id":"%s","success":%s}\n', actionId, success_str)
    writeLines(payload, con)
  }

  registerAction <- function(actionName, callback) {
    handlers[[actionName]] <<- callback
  }

  processActions <- function(timeoutSeconds = 5.0) {
    while (isOpen(con)) {
      line <- readLines(con, n = 1)
      if (length(line) == 0) break
      line <- trimws(line)
      if (nchar(line) == 0) next

      if (grepl('"type":"action"', line)) {
        id_match <- regexpr('"id":"([^"]+)"', line)
        if (id_match != -1) {
          id_str <- regmatches(line, id_match)
          actionId <- gsub('"id":"|"', '', id_str)
        } else {
          next
        }

        action_match <- regexpr('"action":"([^"]+)"', line)
        if (action_match != -1) {
          action_str <- regmatches(line, action_match)
          rawAction <- gsub('"action":"|"', '', action_str)
        } else {
          next
        }

        parenIdx <- regexpr('\\(', rawAction)
        if (parenIdx != -1) {
          name <- trimws(substr(rawAction, 1, parenIdx - 1))
          rparenIdx <- regexpr('\\)', rawAction)
          if (rparenIdx != -1) {
            args_str <- substr(rawAction, parenIdx + 1, rparenIdx - 1)
            args <- trimws(strsplit(args_str, ",")[[1]])
            args <- gsub('^"|"$', '', args)
          } else {
            args <- list()
          }
        } else {
          name <- trimws(rawAction)
          args <- list()
        }

        handler <- handlers[[name]]
        if (!is.null(handler)) {
          respond <- function(success) {
            sendActionResult(actionId, success)
          }
          handler(args, respond)
        } else {
          sendActionResult(actionId, TRUE)
        }
      }
    }
  }

  closeConnection <- function() {
    close(con)
  }

  list(
    sendPerception = sendPerception,
    registerAction = registerAction,
    processActions = processActions,
    close = closeConnection
  )
}
