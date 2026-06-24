The current machine does not support all of the following CPU features that are required by the image: [CX8, CMOV, FXSR, MMX, SSE, SSE2, SSE3, SSSE3, SSE4_1, SSE4_2, POPCNT, LZCNT, AVX, AVX2, BMI1, BMI2, FMA].
Please rebuild the executable with an appropriate setting of the -march option.node:events:486
      throw er; // Unhandled 'error' event
      ^

Error: connect ECONNREFUSED 127.0.0.1:44444
    at TCPConnectWrap.afterConnect [as oncomplete] (node:net:1637:16)
Emitted 'error' event on Panteao instance at:
    at Socket.<anonymous> (/home/kkphoenix/Documentos/Workspace/test/javascript-panteao/node_modules/panteao-js/index.js:156:18)
    at Socket.emit (node:events:520:35)
    at emitErrorNT (node:internal/streams/destroy:170:8)
    at emitErrorCloseNT (node:internal/streams/destroy:129:3)
    at process.processTicksAndRejections (node:internal/process/task_queues:89:21) {
  errno: -111,
  code: 'ECONNREFUSED',
  syscall: 'connect',
  address: '127.0.0.1',
  port: 44444
}

Node.js v24.11.1
