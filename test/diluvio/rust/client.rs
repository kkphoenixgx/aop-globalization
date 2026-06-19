// ============================================================================
// A Muralha de Telemetria — Rust Sensor Validation Client
// ============================================================================
// Connects to the Panteão BDI Engine on 127.0.0.1:44444 and sends a
// sensor_validated(sensor_40) perception, simulating cryptographic validation
// of sensor telemetry. Since the agent only logs this percept (no action is
// dispatched back), we wait 2 seconds for the log to propagate, then exit.
// ============================================================================

use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, Write};
use std::net::TcpStream;
use std::time::{Duration, Instant};

// ---------------------------------------------------------------------------
// Protocol messages
// ---------------------------------------------------------------------------

#[derive(Serialize)]
struct Perception<'a> {
    r#type: &'a str,
    action: &'a str,
    perception: &'a str,
}

#[derive(Deserialize, Debug)]
struct EngineMessage {
    r#type: Option<String>,
    id: Option<String>,
    agent: Option<String>,
    action: Option<String>,
}

#[derive(Serialize)]
struct ActionResult<'a> {
    r#type: &'a str,
    id: &'a str,
    success: bool,
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn elapsed_ms(start: &Instant) -> f64 {
    start.elapsed().as_secs_f64() * 1000.0
}

fn print_banner() {
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║        A MURALHA DE TELEMETRIA — Rust Client               ║");
    println!("║        Sensor Cryptographic Validation Test                 ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

fn main() {
    let total_start = Instant::now();
    print_banner();

    // --- Phase 1: Connect ---------------------------------------------------
    println!("\n[MURALHA] Phase 1 — Connecting to Panteão engine...");
    let connect_start = Instant::now();

    let stream = TcpStream::connect("127.0.0.1:44444").unwrap_or_else(|e| {
        eprintln!("[MURALHA] FAILURE: Could not connect to engine: {}", e);
        std::process::exit(1);
    });
    stream
        .set_read_timeout(Some(Duration::from_secs(3)))
        .expect("Failed to set read timeout");

    println!(
        "[MURALHA]   Connected in {:.2}ms",
        elapsed_ms(&connect_start)
    );

    // Wait 1 second for engine readiness
    println!("[MURALHA]   Waiting 1s for engine readiness...");
    std::thread::sleep(Duration::from_secs(1));

    // --- Phase 2: Simulate cryptographic validation -------------------------
    println!("\n[MURALHA] Phase 2 — Simulating cryptographic sensor validation...");
    let crypto_start = Instant::now();

    // Simulate a lightweight hash check (SHA-256-like delay)
    let sensor_id = "sensor_40";
    let mut checksum: u64 = 0;
    for byte in sensor_id.bytes() {
        checksum = checksum.wrapping_mul(31).wrapping_add(byte as u64);
    }
    println!(
        "[MURALHA]   Sensor '{}' checksum: 0x{:016X}",
        sensor_id, checksum
    );
    println!(
        "[MURALHA]   Crypto validation completed in {:.2}ms",
        elapsed_ms(&crypto_start)
    );

    // --- Phase 3: Send perception -------------------------------------------
    println!("\n[MURALHA] Phase 3 — Sending sensor_validated perception...");
    let send_start = Instant::now();

    let perception = Perception {
        r#type: "perception",
        action: "add",
        perception: "sensor_validated(sensor_40)",
    };

    let mut writer = stream.try_clone().expect("Failed to clone stream");
    let payload = serde_json::to_string(&perception).expect("Failed to serialize perception");
    writeln!(writer, "{}", payload).expect("Failed to send perception");
    writer.flush().expect("Failed to flush");

    println!("[MURALHA]   Perception sent: sensor_validated(sensor_40)");
    println!(
        "[MURALHA]   Send completed in {:.2}ms",
        elapsed_ms(&send_start)
    );

    // --- Phase 4: Listen for any engine responses ---------------------------
    println!("\n[MURALHA] Phase 4 — Listening for engine activity (2s window)...");
    let listen_start = Instant::now();

    let reader = BufReader::new(&stream);
    let mut action_count = 0u32;

    for line_result in reader.lines() {
        // Check if we've exceeded the 2-second listen window
        if listen_start.elapsed() >= Duration::from_secs(2) {
            println!("[MURALHA]   Listen window elapsed (2s).");
            break;
        }

        match line_result {
            Ok(line) => {
                if line.trim().is_empty() {
                    continue;
                }
                println!("[MURALHA]   Engine says: {}", line);

                // Attempt to parse as an action request
                if let Ok(msg) = serde_json::from_str::<EngineMessage>(&line) {
                    if msg.r#type.as_deref() == Some("action") {
                        if let (Some(id), Some(action)) = (&msg.id, &msg.action) {
                            action_count += 1;
                            println!(
                                "[MURALHA]   Unexpected action received: {} (responding OK)",
                                action
                            );
                            let result = ActionResult {
                                r#type: "action_result",
                                id,
                                success: true,
                            };
                            let resp = serde_json::to_string(&result)
                                .expect("Failed to serialize result");
                            writeln!(writer, "{}", resp)
                                .expect("Failed to send action result");
                            writer.flush().expect("Failed to flush");
                        }
                    }
                }
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock
                || e.kind() == std::io::ErrorKind::TimedOut =>
            {
                // Read timeout reached — expected behavior
                println!("[MURALHA]   Read timeout (expected — no action dispatched).");
                break;
            }
            Err(e) => {
                eprintln!("[MURALHA]   Read error: {}", e);
                break;
            }
        }
    }

    // --- Phase 5: Report results --------------------------------------------
    let total_elapsed = elapsed_ms(&total_start);
    println!("\n╔══════════════════════════════════════════════════════════════╗");
    println!("║                    TELEMETRY REPORT                         ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!(
        "║  Connection time:        {:>8.2}ms                          ║",
        elapsed_ms(&connect_start)
    );
    println!(
        "║  Crypto validation:      {:>8.2}ms                          ║",
        elapsed_ms(&crypto_start)
    );
    println!(
        "║  Perception send:        {:>8.2}ms                          ║",
        elapsed_ms(&send_start)
    );
    println!(
        "║  Listen window:          {:>8.2}ms                          ║",
        elapsed_ms(&listen_start)
    );
    println!(
        "║  Actions received:       {:>8}                              ║",
        action_count
    );
    println!(
        "║  Total elapsed:          {:>8.2}ms                          ║",
        total_elapsed
    );
    println!("╚══════════════════════════════════════════════════════════════╝");

    if action_count == 0 {
        println!("\n[MURALHA] Sensor telemetry logged by agent (no action dispatched).");
    }

    println!("\n[DILUVIO] SUCCESS");
    println!("[MURALHA] A Muralha de Telemetria stands firm. Exiting.");
}
