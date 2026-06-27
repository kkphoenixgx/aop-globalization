import { Panteao } from "panteao-js";

let panteao = new Panteao({ project: "./project.jcm" });

await panteao.connect();

console.log("hello?");