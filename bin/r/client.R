con <- socketConnection(host="127.0.0.1", port=40000, blocking=TRUE, server=FALSE)
writeLines('{"type":"perception","action":"add","perception":"test_percept"}', con)
close(con)