import { Panteao } from "panteao-js";

let panteao = new Panteao({ host: '127.0.0.1', port: 44444, project: "./teste.jcm" });

await panteao.connect();

console.log("hello?");

