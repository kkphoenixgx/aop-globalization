#include <panteao.h>
#include <stdio.h>

int main() {
    panteao_t* engine = panteao_create();
    panteao_connect(engine);
    panteao_wait(engine);
    return 0;
}
