// ============================================================
// OPERAÇÃO DILÚVIO - Agente Orquestrador BDI Universal
// O cérebro central que raciocina sobre desastres naturais.
// Agora delegando toda a saída de ações ao hermes_talaria.
// ============================================================

// Crenças iniciais
alert_active(false).

// ---- REGRAS DE PERCEPÇÃO E REAÇÃO ----

// Go: Tempestade IoT - Sensores de nível de água
+water_level(SensorID, L) : L > 90 & alert_active(false) <-
    -alert_active(false);
    +alert_active(true);
    .print("[BDI] ALERTA CRITICO: Nivel ", L, " no sensor ", SensorID);
    .send(hermes_talaria, achieve, update_dashboard("EVACUAR_CIDADE", "critical")).

+water_level(SensorID, L) : L > 50 <-
    .print("[BDI] Nivel elevado: ", L, " no sensor ", SensorID).

// Python: Olhos do Drone - Detecção de vítimas
+victim_spotted(Lat, Lng, Status) : Status == ferido <-
    .print("[BDI] Vitima FERIDA localizada em ", Lat, ", ", Lng);
    .send(hermes_talaria, achieve, dispatch_rescue_bot(Lat, Lng)).

+victim_spotted(Lat, Lng, Status) : true <-
    .print("[BDI] Vitima detectada (", Status, ") em ", Lat, ", ", Lng).

// C/C++: Controlo de comportas
+gate_pressure(GateID, Pressure) : Pressure > 80 <-
    .print("[BDI] Pressao critica na comporta ", GateID, ": ", Pressure);
    .send(hermes_talaria, achieve, open_gate(GateID, 45)).

// Rust: Validação de telemetria
+sensor_validated(SensorID) : true <-
    .print("[BDI] Sensor ", SensorID, " validado pelo Rust (integridade OK)").

// Java: Fundos de emergência
+emergency_declared(Zone) : true <-
    .print("[BDI] Emergencia declarada na zona ", Zone);
    .send(hermes_talaria, achieve, liberate_emergency_funds(Zone, 1000000)).

// C#: Defesa Civil
+military_request(Lat, Lng) : true <-
    .print("[BDI] Pedido de suporte militar para ", Lat, ", ", Lng);
    .send(hermes_talaria, achieve, dispatch_military_support(Lat, Lng)).

// Scala: Saturação do solo
+soil_saturation_critical(Zone) : true <-
    .print("[BDI] Saturacao critica do solo na zona ", Zone);
    .send(hermes_talaria, achieve, evacuate_zone(Zone)).

// R: Previsão meteorológica
+probability_of_flood(P) : P > 80 <-
    .print("[BDI] Probabilidade de inundacao: ", P, "%! Preparando evacuacao...");
    .send(hermes_talaria, achieve, prepare_evacuation("all_zones")).

// Swift/ObjC/Kotlin: Alertas mobile
+evacuation_order(Zone) : true <-
    .print("[BDI] Ordem de evacuacao para zona ", Zone);
    .send(hermes_talaria, achieve, send_push_notification(Zone, "EVACUACAO IMEDIATA")).

// Dart: Coordenadas de resgate
+rescue_coordinates(Lat, Lng) : true <-
    .print("[BDI] Coordenadas de resgate recebidas: ", Lat, ", ", Lng);
    .send(hermes_talaria, achieve, update_rescue_map(Lat, Lng)).

// PHP: Abrigos
+shelter_needed(SchoolID) : true <-
    .print("[BDI] Abrigo necessario na escola ", SchoolID);
    .send(hermes_talaria, achieve, open_shelter(SchoolID)).

// Ruby: Frota de ônibus
+transport_needed(Point) : true <-
    .print("[BDI] Transporte necessario para ponto ", Point);
    .send(hermes_talaria, achieve, redirect_buses_to(Point)).

// Shell: Escalonamento de servidores
+high_latency(Ms) : Ms > 500 <-
    .print("[BDI] Latencia alta detectada: ", Ms, "ms! Escalando servidores...");
    .send(hermes_talaria, achieve, scale_up_servers(2)).

// SQL: Auditoria
+decision_made(Type, Details) : true <-
    .print("[BDI] Decisao registrada: ", Type, " - ", Details);
    log_decision(Type, Details).

// TypeScript/Node: Dashboard
+dashboard_update(Msg) : true <-
    .print("[BDI] Atualizando dashboard: ", Msg);
    .send(hermes_talaria, achieve, update_dashboard(Msg, "info")).
