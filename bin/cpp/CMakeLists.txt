cmake_minimum_required(VERSION 3.10)
project(PanteaoClientCpp)

set(CMAKE_CXX_STANDARD 11)

add_executable(panteao_client client.cpp)
target_link_libraries(panteao_client pthread)
