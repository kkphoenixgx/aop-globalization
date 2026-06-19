#!/bin/bash
# Send perception using netcat
echo '{"type":"perception","action":"add","perception":"test_percept"}' | nc localhost 40000