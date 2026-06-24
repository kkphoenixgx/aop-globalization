import { BdiClient } from "panteao-ts";


let engine = new BdiClient({project: "./test.jcm"});

await engine.connect();

console.log("hello");

setTimeout(()=>{ console.log("ok...");
 }, 5000)
