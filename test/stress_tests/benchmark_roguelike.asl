hp(100).
enemies_around(2).

// Logical Rules for unification stress
threat_level(T) :- hp(H) & enemies_around(E) & T = (E * 100) / H.

+pos(X, Y)[source(game)] : threat_level(T) & T > 50 <- run_away(X, Y).
+pos(X, Y)[source(game)] : threat_level(T) & T <= 50 <- attack_nearest(X, Y).
