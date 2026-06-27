cmake_minimum_required(VERSION 3.10)
project(PanteaoClientCpp)

set(CMAKE_CXX_STANDARD 11)

add_library(panteao_client_cpp STATIC src/panteao_client.cpp)
target_include_directories(panteao_client_cpp PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
