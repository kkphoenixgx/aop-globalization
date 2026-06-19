!start.

+!start : true <-
    do_custom_action("hello_from_agent");
    .wait(1000);
    !start.

+test_system_action : true <-
    .system("ls");
    -test_system_action.
