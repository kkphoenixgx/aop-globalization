#include "panteao_client.h"
int main() {
    panteao::Panteao engine;
    engine.connect("./project.jcm");
    engine.wait();
    return 0;
}