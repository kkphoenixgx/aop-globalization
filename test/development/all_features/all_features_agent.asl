// Test agent for standard library functions, math, lists, strings and dynamic plans.

!start.

+!start : true <-
    .print("==================================================");
    .print("INICIANDO TESTE COMPLETO DE FUNCOES PANTEAO (BDI)");
    .print("==================================================");
    
    // 1. Teste de Identidade
    .my_name(Name);
    .print("Meu nome de agente: ", Name);
    
    // 2. Teste de Matematica e Funcoes
    .print("--- Teste de Funcoes de Matematica ---");
    X = math.sin(3.14159265 / 2);
    Y = math.cos(0);
    S = math.sqrt(16);
    R = math.random(100);
    .print("sin(pi/2) = ", X);
    .print("cos(0) = ", Y);
    .print("sqrt(16) = ", S);
    .print("random(100) = ", R);
    
    // 3. Teste de Strings e Listas
    .print("--- Teste de Strings e Listas ---");
    .concat("Panteao-", "Engine", FullStr);
    .substring("Panteao", FullStr, SubStrPos);
    .print("Concatened String: ", FullStr);
    .print("Position of 'Panteao' in it: ", SubStrPos);
    
    L = [a, b, c, d];
    .length(L, Len);
    .nth(2, L, Element);
    .reverse(L, RevList);
    .print("Lista L = ", L);
    .print("Tamanho de L = ", Len);
    .print("Elemento na posicao 2 = ", Element);
    .print("Lista invertida = ", RevList);
    
    // 4. Teste de Crencas e Consultas
    .print("--- Teste de Crencas e Consultas ---");
    +belief(test_val_1);
    +belief(test_val_2);
    +belief(test_val_1); // duplicate for setof test
    .count(belief(_), CountVal);
    .print("Quantidade de crencas 'belief': ", CountVal);
    
    .findall(V, belief(V), BeliefList);
    .print("findall 'belief': ", BeliefList);
    
    .setof(V, belief(V), BeliefSet);
    .print("setof 'belief' (sem duplicatas): ", BeliefSet);
    
    // 5. Teste de Tipos e Validacoes
    .print("--- Teste de Validacoes de Tipos ---");
    if (.number(123) & .literal(belief(test))) {
        .print("Validacoes de tipo (.number e .literal) passaram!");
    }
    
    // 6. Teste de BDI (Metas e Intencoes)
    .print("--- Teste de Estado BDI (Desires e Intentions) ---");
    if (.desire(start) & .intend(start)) {
        .print("O agente reconhece que deseja e intenciona a meta 'start'!");
    }
    
    // 7. Teste de Alteracao do Belief Base
    .print("--- Teste de Abolish de Crencas ---");
    .abolish(belief(_));
    .count(belief(_), CountAfter);
    .print("Quantidade de crencas apos abolish: ", CountAfter);
    
    // 8. Teste de Planos Dinamicos
    .print("--- Teste de Planos Dinamicos ---");
    .add_plan({ +!dynamic_test : true <- .print("Executando plano dinamico com sucesso!") });
    !dynamic_test;
    
    // 10. Comunicação (Mensagens)
    .print("--- Teste de Comunicacao (Mensagens) ---");
    .my_name(Me);
    .send(Me, tell, loopback_test_msg("ola, eu mesmo!"));
    .wait(100);
    
    // 11. Controlo Temporal e Suspensão
    .print("--- Teste de Controlo Temporal (Wait) ---");
    .print("Esperando 1 segundo...");
    .wait(1000);
    .print("Espera concluida sem bloquear o event loop.");
    
    // 12. Gestão do Ciclo de Vida
    .print("--- Teste de Ciclo de Vida (Criar e Destruir) ---");
    .create_agent(clone_agent, "all_features_agent.asl");
    .wait(200);
    .kill_agent(clone_agent);
    .print("Agente clone_agent criado e destruido com sucesso.");
    
    // 13. Limpeza da Mente (Gestao de Memoria)
    .print("--- Teste de Remocao de Planos (Memory Management) ---");
    .add_plan({ @temp_plan +!temp_goal : true <- .print("Este plano vai ser apagado em breve!") });
    !temp_goal;
    .remove_plan(temp_plan);
    .print("Plano @temp_plan removido com sucesso.");
    
    // 14. Tratamento de Falhas (Recuperacao)
    .print("--- Teste de Tratamento de Falhas ---");
    !test_failure_recovery;
    
    // 9. Teste de Acao Customizada Interceptada
    .print("--- Teste de Acao Nativa Interceptada por C++ ---");
    execute_native_test("teste_completo_funcionando");
    
    .print("==================================================");
    .print("TESTE COMPLETO FINALIZADO COM SUCESSO!");
    .print("==================================================").

+loopback_test_msg(Msg)[source(S)] <-
    .print("Mensagem recebida de ", S, " com conteudo: ", Msg).

+!test_failure_recovery <-
    .print("Tentando executar um plano que vai falhar...");
    .fail;
    .print("Isto nunca deve ser impresso!").

-!test_failure_recovery <-
    .print("Plano de contingencia ativado! Falha capturada e recuperada graciosamente.").
