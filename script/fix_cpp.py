import re

with open('/home/kkphoenix/.gemini/antigravity-cli/brain/bc6b3c0d-011d-4c91-b19d-c0616b55dbbe/scratch/generate_high_level_sdks_v2.py', 'r') as f:
    content = f.read()

# Extract cpp_impl
match = re.search(r'cpp_impl = """(.*?)"""\nwith open', content, re.DOTALL)
if match:
    cpp_code = match.group(1)
    
    # Remove std::string BdiClient::cleanArg(const std::string& arg) { ... }
    cpp_code = re.sub(r'std::string BdiClient::cleanArg\(const std::string& arg\) \{.*?\n\}\n*', '', cpp_code, flags=re.DOTALL)
    
    clean_arg_str = """
static std::string cleanArg(const std::string& arg) {
    std::string s = arg;
    s.erase(0, s.find_first_not_of(" \\t\\r\\n"));
    s.erase(s.find_last_not_of(" \\t\\r\\n") + 1);
    if (s.length() >= 2 && s.front() == '"' && s.back() == '"') {
        s = s.substr(1, s.length() - 2);
    }
    return s;
}

std::pair<std::string, std::vector<std::string>> BdiClient::parseAction(const std::string& actionStr) {"""

    cpp_code = cpp_code.replace("std::pair<std::string, std::vector<std::string>> BdiClient::parseAction(const std::string& actionStr) {", clean_arg_str)
    
    with open('/home/kkphoenix/Documentos/Workspace/1. Pesquisa/Panteão/sdk/cpp/src/panteao_client.cpp', 'w') as f:
        f.write(cpp_code)
    print("Fixed C++ SDK")
else:
    print("Could not find cpp_impl")
