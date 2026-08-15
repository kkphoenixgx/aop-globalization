// broadcast_agent.asl
// Simple agent to test broadcast reception

+earthquake(X)[source(S)] <-
    .print("Wow, I felt the earthquake of magnitude ", X, " broadcasted by ", S, "!");
    ack_broadcast.
