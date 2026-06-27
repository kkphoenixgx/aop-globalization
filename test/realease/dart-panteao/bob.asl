!start.
+!start <- 
    .print("Starting simulation.");
    turn_on_ac(room_1).

+ac_status(on)[source(sensor)] <-
    .print("Sensors detected AC is now ON. Simulation Success.").
