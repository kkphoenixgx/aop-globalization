// ============================================================
// OPERAÇÃO DILÚVIO - Agente Orquestrador BDI Universal
// O cérebro central que raciocina sobre desastres naturais.
// Toda comunicação com o mundo externo via .send(talaria, ...).
// ============================================================

// Crenças iniciais
alert_active(false).

// ---- REGRAS DE PERCEPÇÃO E REAÇÃO ----

// Go: Tempestade IoT - Sensores de nível de água
+water_level(SensorID, L) : L > 90 & alert_active(false) <-
    -alert_active(false);
    +alert_active(true);
    .print("[BDI] ALERTA CRITICO: Nivel ", L, " no sensor ", SensorID);
    .send(talaria, tell, update_dashboard("EVACUAR_CIDADE", "critical")).

+water_level(SensorID, L) : L > 50 <-
    .print("[BDI] Nivel elevado: ", L, " no sensor ", SensorID).

// Python: Olhos do Drone - Detecção de vítimas
+victim_spotted(Lat, Lng, Status) : Status == ferido <-
    .print("[BDI] Vitima FERIDA localizada em ", Lat, ", ", Lng);
    .send(talaria, tell, dispatch_rescue_bot(Lat, Lng)).

+victim_spotted(Lat, Lng, Status) : true <-
    .print("[BDI] Vitima detectada (", Status, ") em ", Lat, ", ", Lng).

// C/C++: Controlo de comportas
+gate_pressure(GateID, Pressure) : Pressure > 80 <-
    .print("[BDI] Pressao critica na comporta ", GateID, ": ", Pressure);
    .send(talaria, tell, open_gate(GateID, 45)).

// Rust: Validação de telemetria
+sensor_validated(SensorID) : true <-
    .print("[BDI] Sensor ", SensorID, " validado pelo Rust (integridade OK)");
    .send(talaria, tell, calibrate_sensor(SensorID)).

// Java: Fundos de emergência
+emergency_declared(Zone) : true <-
    .print("[BDI] Emergencia declarada na zona ", Zone);
    .send(talaria, tell, liberate_emergency_funds(Zone, 1000000)).

// C#: Defesa Civil
+military_request(Lat, Lng) : true <-
    .print("[BDI] Pedido de suporte militar para ", Lat, ", ", Lng);
    .send(talaria, tell, dispatch_military_support(Lat, Lng)).

// Scala: Saturação do solo
+soil_saturation_critical(Zone) : true <-
    .print("[BDI] Saturacao critica do solo na zona ", Zone);
    .send(talaria, tell, evacuate_zone(Zone)).

// R: Previsão meteorológica
+probability_of_flood(P) : P > 80 <-
    .print("[BDI] Probabilidade de inundacao: ", P, "%! Preparando evacuacao...");
    .send(talaria, tell, prepare_evacuation("all_zones")).

// Swift/ObjC/Kotlin: Alertas mobile
+evacuation_order(Zone) : true <-
    .print("[BDI] Ordem de evacuacao para zona ", Zone);
    .send(talaria, tell, send_push_notification(Zone, "EVACUACAO IMEDIATA")).

// Dart: Coordenadas de resgate
+rescue_coordinates(Lat, Lng) : true <-
    .print("[BDI] Coordenadas de resgate recebidas: ", Lat, ", ", Lng);
    .send(talaria, tell, update_rescue_map(Lat, Lng)).

// PHP: Abrigos
+shelter_needed(SchoolID) : true <-
    .print("[BDI] Abrigo necessario na escola ", SchoolID);
    .send(talaria, tell, open_shelter(SchoolID)).

// Ruby: Frota de ônibus
+transport_needed(Point) : true <-
    .print("[BDI] Transporte necessario para ponto ", Point);
    .send(talaria, tell, redirect_buses_to(Point)).

// Shell: Escalonamento de servidores
+high_latency(Ms) : Ms > 500 <-
    .print("[BDI] Latencia alta detectada: ", Ms, "ms! Escalando servidores...");
    .send(talaria, tell, scale_up_servers(2)).

// SQL: Auditoria
+decision_made(Type, Details) : true <-
    .print("[BDI] Decisao registrada: ", Type, " - ", Details);
    .send(talaria, tell, log_decision(Type, Details)).

// TypeScript/Node: Dashboard
+dashboard_update(Msg) : true <-
    .print("[BDI] Atualizando dashboard: ", Msg);
    .send(talaria, tell, update_dashboard(Msg, "info")).

// Testes extras para Javascript
+!js_test_goal(X) <-
    .print("[BDI] Objetivo recebido via performativa achieve: ", X);
    .send(talaria, tell, js_test_action(X)).
