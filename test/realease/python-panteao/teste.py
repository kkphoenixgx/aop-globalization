from panteao import Panteao
import time

def main():
    print("Iniciando Panteao no Python...")
    panteao = Panteao(project="./project.jcm")
    panteao.connect()
    
    print("teste log da minha aplicação")
    
    # Mantém o processo vivo para conseguirmos ver os logs do Java em background
    panteao.wait()

if __name__ == "__main__":
    main()
