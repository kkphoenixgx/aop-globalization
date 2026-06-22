import re

with open("sdk/objc/src/BdiClient.m", "r") as f:
    content = f.read()

content = content.replace("return @{@\"name\": [actionStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @\"args\": @[]};", "return [NSDictionary dictionaryWithObjectsAndKeys:[actionStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @\"name\", [NSArray array], @\"args\", nil];")
content = content.replace("return @{@\"name\": name, @\"args\": @[]};", "return [NSDictionary dictionaryWithObjectsAndKeys:name, @\"name\", [NSArray array], @\"args\", nil];")

with open("sdk/objc/src/BdiClient.m", "w") as f:
    f.write(content)

print("ObjC fixed")
