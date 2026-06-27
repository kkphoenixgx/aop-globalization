import { BdiClient } from "panteao-ts";

let engine = new BdiClient({project: "./project.jcm"});

await engine.connect();
