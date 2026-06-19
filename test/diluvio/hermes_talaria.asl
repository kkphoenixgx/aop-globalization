// ============================================================
// HERMES TALARIA - Agente Comunicador / Gateway IPC
// Decouple socket/TCP action execution from cognitive reasoning.
// ============================================================

// --- REPASSE DE PERCEPÇÕES PARA O ORQUESTRADOR ---

+water_level(SensorID, L)           <- .send(orquestrador, tell, water_level(SensorID, L)).
+victim_spotted(Lat, Lng, Status)   <- .send(orquestrador, tell, victim_spotted(Lat, Lng, Status)).
+gate_pressure(GateID, Pressure)    <- .send(orquestrador, tell, gate_pressure(GateID, Pressure)).
+sensor_validated(SensorID)         <- .send(orquestrador, tell, sensor_validated(SensorID)).
+emergency_declared(Zone)           <- .send(orquestrador, tell, emergency_declared(Zone)).
+military_request(Lat, Lng)         <- .send(orquestrador, tell, military_request(Lat, Lng)).
+soil_saturation_critical(Zone)     <- .send(orquestrador, tell, soil_saturation_critical(Zone)).
+probability_of_flood(P)            <- .send(orquestrador, tell, probability_of_flood(P)).
+rescue_coordinates(Lat, Lng)       <- .send(orquestrador, tell, rescue_coordinates(Lat, Lng)).
+shelter_needed(SchoolID)           <- .send(orquestrador, tell, shelter_needed(SchoolID)).
+transport_needed(Point)            <- .send(orquestrador, tell, transport_needed(Point)).
+high_latency(Ms)                   <- .send(orquestrador, tell, high_latency(Ms)).
+dashboard_update(Msg)              <- .send(orquestrador, tell, dashboard_update(Msg)).

// --- REPASSE DE AÇÕES DO ORQUESTRADOR PARA O CLIENTE ---

+!update_dashboard(X, Y) [source(orquestrador)]          <- update_dashboard(X, Y).
+!dispatch_rescue_bot(Lat, Lng) [source(orquestrador)]   <- dispatch_rescue_bot(Lat, Lng).
+!open_gate(GateID, Angle) [source(orquestrador)]        <- open_gate(GateID, Angle).
+!liberate_emergency_funds(Zone, Amt) [source(orquestrador)] <- liberate_emergency_funds(Zone, Amt).
+!dispatch_military_support(Lat, Lng) [source(orquestrador)] <- dispatch_military_support(Lat, Lng).
+!evacuate_zone(Zone) [source(orquestrador)]            <- evacuate_zone(Zone).
+!prepare_evacuation(Zone) [source(orquestrador)]       <- prepare_evacuation(Zone).
+!send_push_notification(Zone, Msg) [source(orquestrador)] <- send_push_notification(Zone, Msg).
+!update_rescue_map(Lat, Lng) [source(orquestrador)]     <- update_rescue_map(Lat, Lng).
+!open_shelter(SchoolID) [source(orquestrador)]          <- open_shelter(SchoolID).
+!redirect_buses_to(Point) [source(orquestrador)]        <- redirect_buses_to(Point).
+!scale_up_servers(N) [source(orquestrador)]             <- scale_up_servers(N).
