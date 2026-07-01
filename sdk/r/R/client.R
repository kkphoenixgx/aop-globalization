BdiClient <- function(host = "127.0.0.1", port = 0, project = NULL) {
  getFreePort <- function() {
    tryCatch({
      s <- socketConnection(server = TRUE, port = 0, open = "r")
      p <- summary(s)$port
      close(s)
      return(p)
    }, error = function(e) {
      return(44444)
    })
  }

  VERSION <- "1.1.17"

  downloadEngine <- function(binPath) {
    is_win <- .Platform$OS.type == "windows"
    is_mac <- Sys.info()["sysname"] == "Darwin"
    osName <- if (is_win) "win32" else if (is_mac) "darwin" else "linux"
    arch <- tolower(Sys.info()["machine"])
    archStr <- if (grepl("arm|aarch64", arch)) "arm64" else "x64"
    pkgName <- paste0("panteao-engine-", osName, "-", archStr)
    urlStr <- paste0("https://registry.npmjs.org/", pkgName, "/-/", pkgName, "-", VERSION, ".tgz")
    
    cat(sprintf("\033[36m[Panteao]\033[0m Downloading native engine for %s-%s (v%s)...\n", osName, archStr, VERSION))
    
    tmpDir <- tempdir()
    tarFile <- file.path(tmpDir, paste0("engine-", sample(1:1000000, 1), ".tgz"))
    
    curl_bin <- if (is_win) "C:\\Windows\\System32\\curl.exe" else "/usr/bin/curl"
    system2(curl_bin, args = c("-sL", "-o", tarFile, urlStr))
    
    extractDir <- file.path(tmpDir, paste0("extract-", sample(1:1000000, 1)))
    dir.create(extractDir, showWarnings = FALSE)
    
    tar_bin <- if (is_win) "C:\\Windows\\System32\\tar.exe" else "/usr/bin/tar"
    system2(tar_bin, args = c("-xzf", tarFile, "-C", extractDir))
    
    extracted_files <- list.files(extractDir, recursive = TRUE, full.names = TRUE)
    target_name <- if (is_win) "panteao-engine.exe" else "panteao-engine"
    sourcePath <- extracted_files[basename(extracted_files) == target_name]
    
    if (length(sourcePath) > 0) {
      dir.create(dirname(binPath), recursive = TRUE, showWarnings = FALSE)
      file.copy(sourcePath[1], binPath, overwrite = TRUE)
      if (!is_win) {
        Sys.chmod(binPath, mode = "0755")
      }
    }
    
    unlink(tarFile)
    unlink(extractDir, recursive = TRUE)
  }

  findBinary <- function() {
    is_win <- .Platform$OS.type == "windows"
    bin_name <- if (is_win) "panteao-engine.exe" else "panteao-engine"
    if (file.exists(bin_name)) return(file.path(getwd(), bin_name))
    if (file.exists(file.path("bin", bin_name))) return(file.path(getwd(), "bin", bin_name))
    return(bin_name)
  }

  pid <- NULL
  if (!is.null(project)) {
    if (port == 0) {
      port <- getFreePort()
    }
    bin <- findBinary()
    if (basename(bin) == "panteao-engine" || basename(bin) == "panteao-engine.exe") {
      is_win <- .Platform$OS.type == "windows"
      bin <- file.path(getwd(), if (is_win) "panteao-engine.exe" else "panteao-engine")
      if (!file.exists(bin)) {
        downloadEngine(bin)
      }
    }
    pid <- system2(bin, args = c(project, "--port", as.character(port)), wait = FALSE, stdout = "", stderr = "")
    Sys.sleep(0.8)
  } else if (port == 0) {
    port <- 44444
  }

  con <- socketConnection(host = host, port = port, blocking = TRUE, open = "r+")
  
  while (isOpen(con)) {
    line <- readLines(con, n = 1)
    if (length(line) == 0) stop("Connection closed during handshake")
    if (grepl('"type":"mas_ready"', line)) {
      break
    }
  }

  handlers <- list()

  sendMsg <- function(performative, sender, receiver, content) {
    payload <- sprintf('{"type":"message","performative":"%s","sender":"%s","receiver":"%s","content":"%s"}\n', performative, sender, receiver, content)
    writeLines(payload, con)
  }

  sendPerception <- function(action, perception) {
    payload <- sprintf('{"type":"perception","action":"%s","perception":"%s"}\n', action, perception)
    writeLines(payload, con)
  }

  sendActionResult <- function(actionId, success) {
    success_str <- if (success) "true" else "false"
    payload <- sprintf('{"type":"action_result","id":"%s","success":%s}
', actionId, success_str)
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

        action_start <- regexpr('"action":"', line)
        if (action_start != -1) {
          # extract everything after "action":"
          rem <- substr(line, action_start + 10, nchar(line))
          # find the last quote before the end of the JSON object (ignoring spaces/commas)
          # A simple heuristic: find the last quote in 'rem'
          last_quote <- regexpr('"[^"]*$', rem)
          if (last_quote != -1) {
            rawAction <- substr(rem, 1, last_quote - 1)
            rawAction <- gsub('\\\\"', '"', rawAction)
          } else {
            next
          }
        } else {
          next
        }

        parenIdx <- regexpr('\\(', rawAction)
        if (parenIdx != -1) {
          name <- trimws(substr(rawAction, 1, parenIdx - 1))
          rparenIdx <- regexpr('\\)', rawAction)
          if (rparenIdx != -1) {
            args_str <- substr(rawAction, parenIdx + 1, rparenIdx - 1)
            
            # Robust nested parser in R
            chars <- strsplit(args_str, "")[[1]]
            args <- list()
            current <- ""
            inside_quotes <- FALSE
            depth_brackets <- 0
            depth_parens <- 0
            
            if (length(chars) > 0) {
              for (i in 1:length(chars)) {
                c <- chars[i]
                if (c == '"') {
                  inside_quotes <- !inside_quotes
                  current <- paste0(current, c)
                } else if (!inside_quotes && c == '[') {
                  depth_brackets <- depth_brackets + 1
                  current <- paste0(current, c)
                } else if (!inside_quotes && c == ']') {
                  depth_brackets <- depth_brackets - 1
                  current <- paste0(current, c)
                } else if (!inside_quotes && c == '(') {
                  depth_parens <- depth_parens + 1
                  current <- paste0(current, c)
                } else if (!inside_quotes && c == ')') {
                  depth_parens <- depth_parens - 1
                  current <- paste0(current, c)
                } else if (c == ',' && !inside_quotes && depth_brackets == 0 && depth_parens == 0) {
                  args <- c(args, clean_arg(current))
                  current <- ""
                } else {
                  current <- paste0(current, c)
                }
              }
            }
            if (nchar(trimws(current)) > 0) {
              args <- c(args, clean_arg(current))
            }
            args <- unlist(args)
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

  clean_arg <- function(arg) {
    s <- trimws(arg)
    if (startsWith(s, '"') && endsWith(s, '"') && nchar(s) >= 2) {
      return(substr(s, 2, nchar(s) - 1))
    }
    return(s)
  }

  closeConnection <- function() {
    close(con)
    if (!is.null(pid)) {
      try(tools::pskill(pid), silent = TRUE)
    }
  }

  list(
    sendMsg = sendMsg,
    sendPerception = sendPerception,
    registerAction = registerAction,
    processActions = processActions,
    close = closeConnection
  )
}
