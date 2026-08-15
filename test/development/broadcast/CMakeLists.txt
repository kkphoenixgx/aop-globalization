cmake_minimum_required(VERSION 3.10)
project(test_agent)

set(CMAKE_CXX_STANDARD 17)

# Include the C++ SDK
include_directories(/repo/sdk/cpp/include)

add_executable(test_agent main.cpp /repo/sdk/cpp/src/panteao_client.cpp)
