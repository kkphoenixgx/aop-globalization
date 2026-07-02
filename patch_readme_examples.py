import re

with open("README.md", "r") as f:
    text = f.read()

# Python
text = text.replace('engine = Panteao(host="127.0.0.1", port=0, project="./project.jcm")', 'engine = Panteao(host="127.0.0.1", port=0, project="./project.jcm", dev=True)')
# Go
text = text.replace('engine := panteao.New("127.0.0.1:0")', 'engine := panteao.StartAndConnect(panteao.Config{ Host: "127.0.0.1", Port: 0, Project: "./project.jcm", Dev: true })')
# Javascript
text = text.replace("const engine = new Panteao({ project: './project.jcm' });", "const engine = new Panteao({ project: './project.jcm', dev: true });")
# Rust
text = text.replace('let mut engine = Panteao::new("127.0.0.1:0");', 'let mut engine = Panteao::connect_with_project("127.0.0.1:0", Some("./project.jcm"), true).unwrap();')
# Java
text = text.replace('Panteao engine = new Panteao("127.0.0.1", 0);', 'Panteao engine = new Panteao("127.0.0.1", 0, "./project.jcm", true);')
# Kotlin
text = text.replace('val engine = Panteao("127.0.0.1", 0)', 'val engine = Panteao("127.0.0.1", 0, "./project.jcm", true)')
# Scala
text = text.replace('val engine = new Panteao("127.0.0.1", 0)', 'val engine = new Panteao("127.0.0.1", 0, "./project.jcm", true)')
# C++
text = text.replace('engine.connect("127.0.0.1", 0, "./project.jcm");', 'engine.connect("127.0.0.1", 0, "./project.jcm", true);')
# C#
text = text.replace('using var engine = new Panteao.Sdk.Panteao("127.0.0.1", 0, "./project.jcm");', 'using var engine = new Panteao.Sdk.Panteao("127.0.0.1", 0, "./project.jcm", true);')
# Dart
text = text.replace("final engine = Panteao(host: '127.0.0.1', port: 0, project: './project.jcm');", "final engine = Panteao(host: '127.0.0.1', port: 0, project: './project.jcm', dev: true);")
# PHP
text = text.replace('$engine = new Panteao("127.0.0.1", 0);', '$engine = new Panteao("127.0.0.1", 0, "./project.jcm", true);')
# Ruby
text = text.replace("engine = Panteao::Panteao.new('127.0.0.1', 0)", "engine = Panteao::Panteao.new('127.0.0.1', 0, project: './project.jcm', dev: true)")
# Swift
text = text.replace('let engine = Panteao(host: "127.0.0.1", port: 0)', 'let engine = Panteao(host: "127.0.0.1", port: 0, project: "./project.jcm", dev: true)')
# R
text = text.replace('engine <- Panteao$new(host = "127.0.0.1", port = 0)', 'engine <- Panteao$new(host = "127.0.0.1", port = 0, project = "./project.jcm", dev = TRUE)')

with open("README.md", "w") as f:
    f.write(text)

print("README patched successfully")
