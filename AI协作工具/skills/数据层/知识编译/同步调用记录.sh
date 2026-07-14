#!/bin/bash
# 同步调用记录 · 知识编译 v8.1
# 确保 00-运转日志/知识卡片调用记录.md 包含所有卡片，零遗漏
# 退出码：0=全部覆盖，1=有缺失需补写

cd "$(dirname "$0")/../../../.."

python3 -c "
import os, sys

cards = {f[:-3] for f in os.listdir('02-知识卡片/知识卡片') if f.endswith('.md')}
with open('00-运转日志/知识卡片调用记录.md') as f:
    recorded = {l.split('[[')[1].split(']]')[0] for l in f if l.startswith('| [[')}

missing = cards - recorded
if missing:
    print(f'❌ 缺失 {len(missing)} 张卡片，需在调用记录中补写：')
    for m in sorted(missing):
        print(f'  | [[{m}]] | 1 |')
    sys.exit(1)
else:
    print(f'✅ 全部覆盖：{len(cards)} 张卡片 / {len(recorded)} 条记录')
    sys.exit(0)
"
