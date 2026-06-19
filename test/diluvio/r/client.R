#!/usr/bin/env Rscript
# =============================================================================
# Operação Dilúvio — O Vidente Meteorológico (R)
#
# R simulates a statistical flood prediction model.
# Sends a probability_of_flood percept and handles prepare_evacuation actions.
# =============================================================================

library(jsonlite)

HOST          <- "127.0.0.1"
PORT          <- 44444L
TIMEOUT_SEC   <- 5
STARTUP_DELAY <- 1
POLL_INTERVAL <- 0.05  # 50ms between reads

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log_msg <- function(...) {
  cat(sprintf("[DILUVIO] %s\n", paste0(...)))
}

elapsed_ms <- function(t0) {
  dt <- proc.time() - t0
  round(dt[["elapsed"]] * 1000, 2)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

t_total <- proc.time()
log_msg("O Vidente Meteorologico — R test starting")

# 1. Wait for engine readiness
# We wait 1 second for engine readiness, then try to connect
log_msg(sprintf("Waiting %ds for engine readiness...", STARTUP_DELAY))
Sys.sleep(STARTUP_DELAY)

# 2. Connect to engine
t_connect <- proc.time()
con <- tryCatch(
  socketConnection(
    host    = HOST,
    port    = PORT,
    open    = "r+b",
    blocking = TRUE,
    timeout  = TIMEOUT_SEC
  ),
  error = function(e) {
    log_msg("CONNECTION ERROR: ", e$message)
    log_msg("[DILUVIO] FAILURE")
    quit(status = 1, save = "no")
  }
)
log_msg(sprintf("Connected to engine at %s:%d (%sms)", HOST, PORT, elapsed_ms(t_connect)))

# 3. Send perception
t_send <- proc.time()
perception <- toJSON(
  list(
    type       = "perception",
    action     = "add",
    perception = "probability_of_flood(95)"
  ),
  auto_unbox = TRUE
)
writeLines(perception, con)
flush(con)
log_msg(sprintf("Perception sent: probability_of_flood(95) (%sms)", elapsed_ms(t_send)))

# 4. Read lines looking for action request (polling loop with timeout)
action_handled <- FALSE
t_deadline     <- proc.time()[["elapsed"]] + TIMEOUT_SEC

repeat {
  # Check global timeout
  if (proc.time()[["elapsed"]] > t_deadline) {
    log_msg("TIMEOUT — test exceeded 5s")
    log_msg("[DILUVIO] FAILURE")
    close(con)
    quit(status = 1, save = "no")
  }

  line <- tryCatch(
    readLines(con, n = 1, warn = FALSE),
    error = function(e) character(0)
  )

  # No data yet — sleep and retry
  if (length(line) == 0 || nchar(trimws(line)) == 0) {
    Sys.sleep(POLL_INTERVAL)
    next
  }

  line <- trimws(line)
  log_msg(sprintf("Received: %s", line))

  # Try to parse JSON
  msg <- tryCatch(fromJSON(line), error = function(e) NULL)
  if (is.null(msg)) {
    log_msg("Non-JSON line, skipping")
    next
  }

  # Check for action request matching prepare_evacuation
  if (!is.null(msg$type) && msg$type == "action" &&
      !is.null(msg$action) && grepl("^prepare_evacuation", msg$action)) {

    t_action <- proc.time()

    response <- toJSON(
      list(
        type    = "action_result",
        id      = msg$id,
        success = TRUE
      ),
      auto_unbox = TRUE
    )
    writeLines(response, con)
    flush(con)

    action_ms <- elapsed_ms(t_action)

    log_msg(sprintf("Action handled: %s", msg$action))
    log_msg(sprintf("  Agent : %s", ifelse(is.null(msg$agent), "unknown", msg$agent)))
    log_msg(sprintf("  ID    : %s", msg$id))
    log_msg(sprintf("  Response sent (%sms)", action_ms))

    action_handled <- TRUE
    break
  }
}

# 5. Print timing metrics
total_ms <- elapsed_ms(t_total)
log_msg("--- Timing Metrics ---")
log_msg(sprintf("  Total elapsed    : %sms", total_ms))
log_msg(sprintf("  Connection time  : %sms", elapsed_ms(t_connect)))
log_msg("--- Test Complete ---")

if (action_handled) {
  log_msg("[DILUVIO] SUCCESS")
} else {
  log_msg("[DILUVIO] FAILURE")
}

close(con)
quit(status = ifelse(action_handled, 0, 1), save = "no")
