#include <iostream>
#include <thread>
#include "panteao_client.h"

int main() {
    std::cout << "Iniciando Panteao no C++...\n" << std::flush;
    
    panteao::BdiClient client;
    client.connect("127.0.0.1", 0, "./project.jcm");
    
    std::cout << "teste log da minha aplicação C++\n" << std::flush;
    
    // Mantém o processo vivo e cuidando dos logs até um Ctrl+C
    client.wait();
    
    return 0;
}
