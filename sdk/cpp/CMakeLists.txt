cmake_minimum_required(VERSION 3.10)
project(PanteaoClientCpp)

set(CMAKE_CXX_STANDARD 11)

include_directories(include)

add_library(panteao_client_cpp STATIC src/panteao_client.cpp)
