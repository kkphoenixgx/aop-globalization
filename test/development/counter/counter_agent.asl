// Agent that monitors a counter and resets it when it reaches 10.

+counter(10) : true <-
    .print("Opa! O contador chegou a 10. Vou zerar essa bagaça agora!");
    reset_counter.
