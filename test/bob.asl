counter(1).

!start.

+!start : counter(N) <-
    .print("Hello");
    -+counter(N+1);
    .wait(1000);
    !start
.
