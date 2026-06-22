use panteao_client::BdiClient;
use std::process;
use std::thread;
use std::time::Duration;

fn main() {
    println!("[DILUVIO] Rust client starting");
    
    let mut client = match BdiClient::connect("127.0.0.1:44444") {
        Ok(c) => c,
        Err(e) => {
            println!("[DILUVIO] FAILURE: {}", e);
            process::exit(1);
        }
    };

    client.register_action("calibrate_sensor", |_args, respond| {
        println!("[DILUVIO] Action handled: calibrate_sensor");
        respond(true);
        println!("[DILUVIO] SUCCESS");
        process::exit(0);
    });


    
    println!("[DILUVIO] Connected!");
    if let Err(e) = client.send_msg("tell", "external", "orquestrador", "sensor_validated(99)") {
        println!("[DILUVIO] FAILURE: {}", e);
        process::exit(1);
    }

    thread::sleep(Duration::from_secs(5));
    println!("[DILUVIO] TIMEOUT");
    process::exit(1);
}
