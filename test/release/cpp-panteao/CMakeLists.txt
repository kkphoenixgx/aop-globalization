cmake_minimum_required(VERSION 3.10)
project(CppTeste)

set(CMAKE_CXX_STANDARD 11)

# Adiciona a subpasta que acabamos de baixar do GitHub como um módulo do CMake
add_subdirectory(panteao-sdk)

add_executable(cpp_teste main.cpp)

# Linka a nossa aplicação ao SDK e importa todos os headers automaticamente!
target_link_libraries(cpp_teste panteao_client_cpp)
