counter(1).

!start.

+!start : counter(N) <-
    .print("Hello");
    do_something(N);
    -+counter(N+1);
    .wait(1000);
    !start
.

