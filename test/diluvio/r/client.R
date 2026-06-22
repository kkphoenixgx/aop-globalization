#!/usr/bin/env Rscript
# =============================================================================
# Operação Dilúvio — O Vidente Meteorológico (R)
# =============================================================================

library(jsonlite)
source("sdk/R/client.R")

HOST          <- "127.0.0.1"
PORT          <- 44444L
TIMEOUT_SEC   <- 5
STARTUP_DELAY <- 1

log_msg <- function(...) {
  cat(sprintf("[DILUVIO] %s\n", paste0(...)))
}

elapsed_ms <- function(t0) {
  dt <- proc.time() - t0
  round(dt[["elapsed"]] * 1000, 2)
}

t_total <- proc.time()
log_msg("O Vidente Meteorologico — R test starting")

log_msg(sprintf("Waiting %ds for engine readiness...", STARTUP_DELAY))
Sys.sleep(STARTUP_DELAY)

t_connect <- proc.time()
client <- BdiClient(host = HOST, port = PORT)
log_msg(sprintf("Connected to engine at %s:%d (%sms)", HOST, PORT, elapsed_ms(t_connect)))

t_send <- proc.time()
  client$sendMsg("tell", "external", "orquestrador", "probability_of_flood(90)")

action_handled <- FALSE
client$registerAction("prepare_evacuation", function(args, respond) {
  log_msg(sprintf("Action handled: prepare_evacuation"))
  respond(TRUE)
  action_handled <<- TRUE
})

# Read loop using the SDK
t_deadline <- proc.time()[["elapsed"]] + TIMEOUT_SEC
while (proc.time()[["elapsed"]] < t_deadline && !action_handled) {
  # Call processActions to handle one action (or read line by line)
  # R SDK processActions is a while loop, but it will read until EOF or timeout
  # We can run it in a tryCatch to read until action is handled
  tryCatch({
    client$processActions()
  }, error = function(e) {
    # Ignore errors/timeouts
  })
}

total_ms <- elapsed_ms(t_total)
log_msg("--- Timing Metrics ---")
log_msg(sprintf("  Total elapsed    : %sms", total_ms))
log_msg(sprintf("  Connection time  : %sms", elapsed_ms(t_connect)))
log_msg("--- Test Complete ---")

if (action_handled) {
  cat("[DILUVIO] SUCCESS\n")
} else {
  cat("[DILUVIO] FAILURE\n")
}

client$close()
quit(status = ifelse(action_handled, 0, 1), save = "no")
