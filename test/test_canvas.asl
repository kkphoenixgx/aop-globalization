!navigate.

+!navigate : target_pos(TX, TY) & square_pos(SX, SY) & SX == TX & SY == TY <-
    celebrate;
    .print("Cheguei ao destino!").

+!navigate : target_pos(TX, TY) & square_pos(SX, SY) & (SX \== TX | SY \== TY) <-
    .print("Posicao atual: (", SX, ",", SY, ") - Destino: (", TX, ",", TY, ")");
    !calculate_step(SX, SY, TX, TY, NX, NY);
    move(NX, NY);
    .wait(100);
    !navigate.

+!calculate_step(SX, SY, TX, TY, NX, NY) : SX < TX & SY < TY <- NX = SX + 10; NY = SY + 10.
+!calculate_step(SX, SY, TX, TY, NX, NY) : SX > TX & SY < TY <- NX = SX - 10; NY = SY + 10.
+!calculate_step(SX, SY, TX, TY, NX, NY) : SX < TX & SY > TY <- NX = SX + 10; NY = SY - 10.
+!calculate_step(SX, SY, TX, TY, NX, NY) : SX > TX & SY > TY <- NX = SX - 10; NY = SY - 10.
+!calculate_step(SX, SY, TX, TY, NX, NY) : SX < TX & SY == TY <- NX = SX + 10; NY = SY.
+!calculate_step(SX, SY, TX, TY, NX, NY) : SX > TX & SY == TY <- NX = SX - 10; NY = SY.
+!calculate_step(SX, SY, TX, TY, NX, NY) : SX == TX & SY < TY <- NX = SX; NY = SY + 10.
+!calculate_step(SX, SY, TX, TY, NX, NY) : SX == TX & SY > TY <- NX = SX; NY = SY - 10.
+!calculate_step(SX, SY, TX, TY, NX, NY) : true <- NX = SX; NY = SY.
