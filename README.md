# Panteão BDI Engine (Coprocessador BDI)

O **Panteão** é uma isolação perfeita do motor BDI do Jason (`jason-interpreter`) adaptado para rodar em múltiplos ambientes. Ele expõe a execução do ciclo de raciocínio BDI tanto para ambientes de servidor (via Node.js e comunicação por Sockets TCP IPC) quanto de cliente (via Browser rodando no WebAssembly com o CheerpJ 17).

Com o Panteão, você pode embutir inteligência BDI em qualquer arquitetura, incluindo projetos em C++, Python, Rust, ou Frontend Javascript tradicional, delegando o ciclo cognitivo (crenças, intenções e planos) ao motor Jason enquanto implementa as ações físicas e percepções no seu ecossistema nativo.

---

## 🚀 Arquitetura & Modos de Funcionamento

### 1. Servidor (IPC por Sockets TCP)
No servidor, o Node.js gerencia e inicializa o motor Java (ou binário compilado nativamente via GraalVM). A comunicação ocorre por meio de sockets locais com mensagens formatadas em JSON.
* **Auto-Recovery:** O proxy Node.js reinicializa o motor automaticamente em caso de crash.
* **Anti-Coma:** Um timeout configurável previne que agentes fiquem travados indefinidamente esperando o retorno de uma ação.
* **Segurança OOM:** Proteção interna do buffer do socket limita o consumo excessivo de memória em rajadas de eventos.

### 2. Cliente (Browser Sandbox com CheerpJ)
No browser, o motor Jason é executado no WebAssembly utilizando o **CheerpJ 4.3 (Java 17 JRE)**.
* **Interop Nativo Java-JS:** As ações declaradas no Jason são mapeadas em runtime e interceptadas no frontend diretamente no Javascript.
* **Sandbox de Segurança:** Ações nativas de acesso ao sistema operacional (como `.system`) são bloqueadas para evitar exceções e vulnerabilidades de segurança no ambiente do browser.

---

## 🛠️ Automação de Reflection (Manutenibilidade Completa)

O maior desafio ao compilar o Jason via GraalVM Native Image é o uso massivo de carregamento dinâmico de classes (reflection) para as ações padrão (`jason.stdlib.*`) e ações customizadas.

Para resolver isso de forma 100% automatizada e evitar `ClassNotFoundException`, a tarefa customizada `generateReflectionConfig` no `build.gradle`:
1. **Varre as dependências** do classpath em tempo de build para ler o jar do `jason-interpreter`.
2. **Descobre todas as classes stdlib** do Jason dinamicamente.
3. **Escaneia a pasta local `src/main/java`** para registrar automaticamente qualquer ação customizada criada por você (como `jason.stdlib.system`).
4. **Gera o arquivo `reflect-config.json`** de forma limpa e sem duplicidade de classes antes da compilação nativa.

**Se uma nova versão do Jason for lançada:**
Basta alterar a versão em `build.gradle` e rodar a compilação. Nenhuma alteração manual de mapeamento é necessária!

---

## 📦 Como Compilar e Executar

### Pré-requisitos
* **Java SDK 17** (com GraalVM para compilação nativa).
* **Node.js 18+**.
* **Gradle** (incluso via `./gradlew`).

### Comandos Disponíveis

* **Compilar o JAR Shadow (Recomendado/Rápido):**
  ```bash
  npm run build:jar
  ```
  Isso gera o arquivo gordo `build/libs/jason-ipc-all.jar` com todas as dependências embutidas, pronto para rodar em qualquer máquina com JVM.

* **Compilar para Executável Nativo (GraalVM):**
  ```bash
  ./gradlew nativeCompile copyNativeEngine
  ```
  Gera o executável otimizado nativo `bin/panteao-engine` (ou `panteao-engine.exe` no Windows) sem necessidade de JVM para rodar.

* **Executar o Servidor Web de Teste (Browser Sandbox):**
  ```bash
  npm run serve
  ```
  Acesse `http://localhost:8080` para interagir com a interface web sandbox.

* **Executar Teste Automatizado de IPC (Node.js):**
  ```bash
  node test_ipc.js
  ```

---

## 📄 Exemplo de Uso (Node.js)

```javascript
const { Panteao } = require('./index');

const engine = new Panteao({
    project: 'test/test_ipc.jcm',
    port: 0,              // 0 para alocação dinâmica de porta livre
    actionTimeout: 3000,  // 3 segundos de limite anti-coma
    autoRestart: true     // Auto-reinicialização
});

engine.on('connect', () => {
    console.log("Conectado ao motor BDI!");
    engine.addPercept("tempo(chuvoso)"); // Injeta percepção
});

engine.on('action', (agent, action, callback) => {
    console.log(`Ação interceptada: agente=${agent}, acao=${action}`);
    // Executa a lógica nativa e retorna o resultado para o Jason
    callback(true); 
});

engine.start();
```

---

## 🔌 Clientes Multi-Linguagem (TCP IPC)

O Panteão BDI expõe um protocolo de comunicação baseado em Sockets TCP usando mensagens JSON delimitadas por quebra de linha (`\n`). 

Para rodar seus agentes integrados com outras linguagens de programação, fornecemos modelos de clientes prontos para uso no diretório `bin/`:

### 1. C++ (`bin/cpp/`)
* **Código Fonte:** [client.cpp](file:///home/kkphoenix/Documentos/Workspace/1.%20Pesquisa/Pante%C3%A3o/bin/cpp/client.cpp)
* **Como Compilar:**
  ```bash
  g++ -std=c++11 -pthread bin/cpp/client.cpp -o bin/cpp/client
  ```
* **Como Executar:**
  ```bash
  ./bin/cpp/client <porta>
  ```

### 2. Python (`bin/python/`)
* **Código Fonte:** [client.py](file:///home/kkphoenix/Documentos/Workspace/1.%20Pesquisa/Pante%C3%A3o/bin/python/client.py)
* **Como Executar:**
  ```bash
  python bin/python/client.py <porta>
  ```

### 3. JavaScript / Node.js (`bin/js/`)
* **Código Fonte:** [client.js](file:///home/kkphoenix/Documentos/Workspace/1.%20Pesquisa/Pante%C3%A3o/bin/js/client.js)
* **Como Executar:**
  ```bash
  node bin/js/client.js <porta>
  ```
