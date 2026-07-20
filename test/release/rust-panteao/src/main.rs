use panteao::Panteao;
fn main() {
    let mut engine = Panteao::connect(Some("./project.jcm")).unwrap();
    engine.wait();
}