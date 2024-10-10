import subprocess
import os
import shutil

fontUse = '''
  fonts:
    - family: font
      fonts:
        - asset: fonts/NotoSansSC-Regular.ttf
'''

# 读 pubspec.yaml 文件内容
with open('pubspec.yaml', 'r') as file:
    content = file.read()

# 追加字体到 pubspec.yaml
with open('pubspec.yaml', 'a') as file:
    file.write(fontUse)

# 构建 Windows 项目
subprocess.run(["flutter", "build", "windows"], shell=True, check=True)

# 还原 pubspec.yaml
with open('pubspec.yaml', 'w') as file:
    file.write(content)

# 删除旧的 zip 文件
zip_file = "build/app-windows.zip"
if os.path.exists(zip_file):
    os.remove(zip_file)

# 提取项目版本号
version = content.split('version: ')[1].split('+')[0]

# 压缩构建好的文件
output_zip = f"build/windows/kostori-{version}-windows.zip"
shutil.make_archive(output_zip.replace('.zip', ''), 'zip', "build/windows/x64/runner/Release")

# 读取并更新 Inno Setup 脚本
with open('windows/build.iss', 'r') as file:
    issContent = file.read()

newContent = issContent.replace("{{version}}", version).replace("{{root_path}}", os.getcwd())

with open('windows/build.iss', 'w') as file:
    file.write(newContent)

# 运行 Inno Setup 脚本
subprocess.run(["iscc", "windows/build.iss"], shell=True, check=True)

# 还原 Inno Setup 脚本内容
with open('windows/build.iss', 'w') as file:
    file.write(issContent)