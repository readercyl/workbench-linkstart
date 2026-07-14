#!/usr/bin/env python3
"""知识网络拓扑结构分析 —— 连通分量、最短路径、度分布、介数中心性、关节点检测。
同时支持低链卡列表、仪表盘数据输出——一次扫描替代原 链接密度扫描.sh + generate_dashboard_data.py。

用法：
    python3 analyze_network.py --cards-dir <path> [--json] [--output-index PATH]
                               [--low-link-threshold N] [--output-dashboard PATH]

输出：
    --json                 输出 JSON 到 stdout
    --output-index PATH    输出网络索引缓存 JSON
    --low-link-threshold N 在 JSON 输出中包含链接数 < N 的卡片列表（默认 0=不输出）
    --output-dashboard PATH 输出仪表盘数据 JSON（替代 generate_dashboard_data.py）
    默认                  人类可读文本输出
"""

import re
import os
import sys
import json
import argparse
from collections import defaultdict, deque, Counter
from datetime import datetime, timezone


def build_graph(cards_dir):
    """解析卡片目录，构建无向图。返回 (adj, card_names, name_to_idx, dead_links)。"""
    card_files = [f for f in os.listdir(cards_dir) if f.endswith('.md')]
    card_names = [f[:-3] for f in card_files]
    name_to_idx = {name: i for i, name in enumerate(card_names)}
    n = len(card_names)

    adj = [[] for _ in range(n)]
    dead_links = []

    for f in card_files:
        card_name = f[:-3]
        i = name_to_idx[card_name]
        filepath = os.path.join(cards_dir, f)
        with open(filepath, 'r', encoding='utf-8') as fh:
            content = fh.read()

        # 排除 **来源** 行之后的内容——来源链接不计入概念入度
        body = content.split('**来源**')[0] if '**来源**' in content else content
        links = re.findall(r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]', body)
        for link in links:
            link = link.strip()
            if link in name_to_idx:
                j = name_to_idx[link]
                if j != i and j not in adj[i]:
                    adj[i].append(j)
                    adj[j].append(i)  # 无向图
            else:
                dead_links.append((card_name, link))

    return adj, card_names, name_to_idx, dead_links, card_files


def find_connected_components(adj, n):
    """BFS 找所有连通分量，按大小降序返回。"""
    visited = [False] * n
    components = []

    for start in range(n):
        if visited[start]:
            continue
        queue = deque([start])
        visited[start] = True
        comp = []
        while queue:
            v = queue.popleft()
            comp.append(v)
            for w in adj[v]:
                if not visited[w]:
                    visited[w] = True
                    queue.append(w)
        components.append(comp)

    components.sort(key=len, reverse=True)
    return components


def all_pairs_shortest_paths(adj, n):
    """全对最短路径 BFS。返回 (all_distances, diameter, farthest_pair, avg, median)。"""
    all_dist = []
    diameter = 0
    farthest_pair = (0, 0)

    for start in range(n):
        dist = [-1] * n
        q = deque([start])
        dist[start] = 0
        while q:
            v = q.popleft()
            for w in adj[v]:
                if dist[w] == -1:
                    dist[w] = dist[v] + 1
                    q.append(w)

        reachable = [d for d in dist if d > 0]
        all_dist.extend(reachable)
        max_d = max((d for d in dist if d >= 0), default=0)
        if max_d > diameter:
            diameter = max_d
            farthest = max((i for i, d in enumerate(dist) if d == max_d))
            farthest_pair = (start, farthest)

    avg = sum(all_dist) / len(all_dist) if all_dist else 0
    median = sorted(all_dist)[len(all_dist) // 2] if all_dist else 0
    return all_dist, diameter, farthest_pair, avg, median


def degree_distribution(adj, n):
    """度分布统计。"""
    degrees = [len(a) for a in adj]
    sorted_deg = sorted(degrees)
    percentiles = {}
    for p in [10, 25, 50, 75, 90, 95, 99]:
        idx = int(p / 100 * n)
        percentiles[f"P{p}"] = sorted_deg[idx] if idx < n else sorted_deg[-1]
    return {
        "avg": sum(degrees) / n,
        "max": max(degrees),
        "min": min(degrees),
        "percentiles": percentiles,
        "degrees": degrees,
    }


def betweenness_centrality(adj, n):
    """Brandes 算法计算精确介数中心性（无向图）。"""
    betweenness = [0.0] * n

    for s in range(n):
        S = []
        P = [[] for _ in range(n)]
        sigma = [0] * n
        sigma[s] = 1
        d = [-1] * n
        d[s] = 0
        Q = deque([s])

        while Q:
            v = Q.popleft()
            S.append(v)
            for w in adj[v]:
                if d[w] < 0:
                    Q.append(w)
                    d[w] = d[v] + 1
                if d[w] == d[v] + 1:
                    sigma[w] += sigma[v]
                    P[w].append(v)

        delta = [0.0] * n
        while S:
            w = S.pop()
            for v in P[w]:
                delta[v] += (sigma[v] / sigma[w]) * (1 + delta[w])
            if w != s:
                betweenness[w] += delta[w]

    # 归一化
    if n > 2:
        norm = (n - 1) * (n - 2) / 2
        betweenness = [b / 2 / norm for b in betweenness]
    return betweenness


def articulation_points_tarjan(adj, n):
    """Tarjan 算法找关节点。"""
    visited = [False] * n
    disc = [-1] * n
    low = [-1] * n
    parent = [-1] * n
    ap = [False] * n
    time_counter = [0]

    def dfs(u):
        children = 0
        visited[u] = True
        time_counter[0] += 1
        disc[u] = low[u] = time_counter[0]

        for v in adj[u]:
            if not visited[v]:
                children += 1
                parent[v] = u
                dfs(v)
                low[u] = min(low[u], low[v])
                if parent[u] == -1 and children > 1:
                    ap[u] = True
                if parent[u] != -1 and low[v] >= disc[u]:
                    ap[u] = True
            elif v != parent[u]:
                low[u] = min(low[u], disc[v])

    for i in range(n):
        if not visited[i]:
            dfs(i)

    return [i for i in range(n) if ap[i]]


def check_health(metrics):
    """根据阈值判定健康度。返回 (grade, issues)。"""
    issues = []

    n_components = metrics["connected_components"]
    if n_components == 1:
        pass  # 🟢
    elif n_components <= 3:
        issues.append({"level": "🟡", "msg": f"存在 {n_components} 个连通分量，网络出现裂痕"})
    else:
        issues.append({"level": "🔴", "msg": f"存在 {n_components} 个连通分量，网络严重碎片化"})

    avg_path = metrics["avg_shortest_path"]
    if avg_path <= 5:
        pass
    elif avg_path <= 7:
        issues.append({"level": "🟡", "msg": f"平均最短路径 {avg_path:.1f} 跳，网络开始稀疏"})
    else:
        issues.append({"level": "🔴", "msg": f"平均最短路径 {avg_path:.1f} 跳，信息检索效率低"})

    diameter = metrics["diameter"]
    if diameter <= 8:
        pass
    elif diameter <= 12:
        issues.append({"level": "🟡", "msg": f"网络直径 {diameter} 跳，存在远端信息孤岛"})
    else:
        issues.append({"level": "🔴", "msg": f"网络直径 {diameter} 跳，信息孤岛严重"})

    articulation_count = metrics["articulation_points_count"]
    if articulation_count == 0:
        pass
    elif articulation_count <= 3:
        issues.append({"level": "🟡", "msg": f"存在 {articulation_count} 个关节点——单点故障风险"})
    else:
        issues.append({"level": "🔴", "msg": f"存在 {articulation_count} 个关节点——网络冗余度不足"})

    isolated = metrics["isolated_nodes"]
    if isolated == 0:
        pass
    elif isolated <= 5:
        issues.append({"level": "🟡", "msg": f"存在 {isolated} 个孤立节点——缺链"})
    else:
        issues.append({"level": "🔴", "msg": f"存在 {isolated} 个孤立节点——大量卡片脱离网络"})

    # 综合等级
    if any(i["level"] == "🔴" for i in issues):
        grade = "🔴"
    elif any(i["level"] == "🟡" for i in issues):
        grade = "🟡"
    else:
        grade = "🟢"

    return grade, issues


def build_dashboard(cards_dir, adj, card_names, deg_stats, metrics, top_hubs):
    """构建仪表盘数据（替代 generate_dashboard_data.py）。"""
    n = len(card_names)
    repo = os.path.dirname(os.path.dirname(cards_dir))

    # 1. 度分布分桶
    dist = Counter()
    for d in deg_stats["degrees"]:
        if d < 3: dist['<3'] += 1
        elif d <= 8: dist['3-8'] += 1
        elif d <= 14: dist['9-14'] += 1
        else: dist['15+'] += 1

    # 2. MOC 大小
    moc_dir = os.path.join(repo, 'MOC')
    moc_sizes = {}
    if os.path.isdir(moc_dir):
        for fname in sorted(os.listdir(moc_dir)):
            if not fname.endswith('.md'): continue
            with open(os.path.join(moc_dir, fname)) as f:
                content = f.read()
            moc_sizes[fname[:-3]] = len(re.findall(r'^- \[\[', content, re.MULTILINE))

    # 3. 双向链接比例（从邻接表直接计算，不重复扫描卡片）
    bi = 0
    total_pairs = 0
    for i in range(n):
        for j in adj[i]:
            if i < j:  # 无向图，每对只算一次
                total_pairs += 1
                if i in adj[j]:
                    bi += 1

    ni = metrics.get("dead_links", 0)
    return {
        'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'card_count': n,
        'total_edges': metrics['total_edges'],
        'diameter': metrics['diameter'],
        'avg_shortest_path': metrics['avg_shortest_path'],
        'dead_links_count': ni if isinstance(ni, int) else len(ni),
        'articulation_points_count': metrics['articulation_points_count'],
        'top_hubs': [{"name": h['name'], "degree": h['degree']} for h in top_hubs[:10]] if top_hubs else [],
        'link_distribution': dict(dist),
        'low_link_lt2': dist.get('<3', 0),
        'low_link_lt3': dist.get('<3', 0),
        'bidirectional_pct': round(bi * 100 / total_pairs, 1) if total_pairs else 0,
        'bidirectional_pairs': bi,
        'total_pairs': total_pairs,
        'moc_sizes': moc_sizes,
    }


def main():
    parser = argparse.ArgumentParser(description="知识网络拓扑结构分析")
    parser.add_argument("--cards-dir", required=True, help="知识卡片目录路径")
    parser.add_argument("--json", action="store_true", help="输出 JSON 格式")
    parser.add_argument("--output-index", type=str, default=None, help="输出网络索引缓存 JSON 文件路径")
    parser.add_argument("--low-link-threshold", type=int, default=0, help="低链卡阈值，在 JSON 输出中包含链接数 < N 的卡片列表")
    parser.add_argument("--output-dashboard", type=str, default=None, help="输出仪表盘数据 JSON 文件路径（替代 generate_dashboard_data.py）")
    args = parser.parse_args()

    cards_dir = args.cards_dir
    if not os.path.isdir(cards_dir):
        print(f"错误：目录不存在 {cards_dir}", file=sys.stderr)
        sys.exit(1)

    # 1. 建图
    adj, card_names, name_to_idx, dead_links, card_files = build_graph(cards_dir)
    n = len(card_names)
    edges = sum(len(a) for a in adj) // 2

    # 2. 连通分量
    components = find_connected_components(adj, n)
    # 孤立节点 = 度为 0
    isolated = [i for i in range(n) if len(adj[i]) == 0]

    # 3. 最短路径
    all_dist, diameter, farthest_pair, avg_path, median_path = all_pairs_shortest_paths(adj, n)

    # 4. 度分布
    deg_stats = degree_distribution(adj, n)

    # 5. 介数中心性
    betweenness = betweenness_centrality(adj, n)

    # 6. 关节点
    ap_indices = articulation_points_tarjan(adj, n)

    # 7. 健康度判定
    metrics = {
        "total_cards": n,
        "total_edges": edges,
        "connected_components": len(components),
        "largest_component_size": len(components[0]) if components else 0,
        "isolated_nodes": len(isolated),
        "avg_shortest_path": round(avg_path, 2),
        "median_shortest_path": median_path,
        "diameter": diameter,
        "avg_degree": round(deg_stats["avg"], 1),
        "articulation_points_count": len(ap_indices),
        "dead_links": len(dead_links),
    }
    grade, issues = check_health(metrics)

    if args.json:
        # JSON 输出
        top_hubs = sorted(
            enumerate(zip(deg_stats["degrees"], betweenness)),
            key=lambda x: x[1][0],
            reverse=True,
        )[:20]
        top_bridges = sorted(
            enumerate(betweenness), key=lambda x: x[1], reverse=True
        )[:20]

        output = {
            "metrics": metrics,
            "grade": grade,
            "issues": issues,
            "degree_percentiles": deg_stats["percentiles"],
            "top_hubs": [{"name": card_names[i], "degree": d, "betweenness": round(b, 6)} for i, (d, b) in top_hubs],
            "top_bridges": [{"name": card_names[i], "betweenness": round(betweenness[i], 6)} for i, _ in top_bridges],
            "articulation_points": [{"name": card_names[i], "degree": deg_stats["degrees"][i]} for i in ap_indices],
            "small_components": [
                {"size": len(c), "cards": [card_names[i] for i in c[:10]]}
                for c in components[1:]  # 第一个是最大分量，其余是小分量
            ],
        }
        if farthest_pair[0] < n and farthest_pair[1] < n:
            output["farthest_pair"] = {
                "from": card_names[farthest_pair[0]],
                "to": card_names[farthest_pair[1]],
                "distance": diameter,
            }

        # 低链卡列表（--low-link-threshold 指定时输出）
        if args.low_link_threshold > 0:
            low_link_cards = []
            for i in range(n):
                if deg_stats["degrees"][i] < args.low_link_threshold:
                    low_link_cards.append({
                        "name": card_names[i],
                        "links": deg_stats["degrees"][i],
                    })
            low_link_cards.sort(key=lambda x: x["links"])
            output["low_link_cards"] = low_link_cards
            output["low_link_count"] = len(low_link_cards)
            output["low_link_threshold"] = args.low_link_threshold

        print(json.dumps(output, ensure_ascii=False, indent=2))

    # 仪表盘输出（--output-dashboard）
    if args.output_dashboard:
        top_hubs_for_dashboard = sorted(
            enumerate(zip(deg_stats["degrees"], betweenness)),
            key=lambda x: x[1][0], reverse=True
        )[:20]
        top_hubs_list = [{"name": card_names[i], "degree": d, "betweenness": round(b, 6)}
                         for i, (d, b) in top_hubs_for_dashboard]
        dashboard = build_dashboard(cards_dir, adj, card_names, deg_stats, metrics, top_hubs_list)
        dashboard_path = os.path.abspath(args.output_dashboard)
        os.makedirs(os.path.dirname(dashboard_path), exist_ok=True)
        with open(dashboard_path, 'w', encoding='utf-8') as f:
            json.dump(dashboard, f, ensure_ascii=False, indent=2)
        size_kb = os.path.getsize(dashboard_path) / 1024
        print(f"📊 仪表盘数据已写入: {dashboard_path} ({size_kb:.1f}KB)", file=sys.stderr)

    if args.output_index:
        from datetime import datetime, timezone
        # 计算概念入度（排除来源行 + MOC 目录引用）
        in_degree = [0] * n
        for i in range(n):
            for j in adj[i]:
                in_degree[j] += 1

        # 检测跨 MOC 标注
        cross_moc = {}
        for f in card_files:
            card_name = f[:-3]
            filepath = os.path.join(cards_dir, f)
            with open(filepath, 'r', encoding='utf-8') as fh:
                content = fh.read()
            match = re.search(r'<!--\s*跨MOC:\s*(.+?)\s*-->', content)
            if match:
                cross_moc[card_name] = [m.strip() for m in match.group(1).split(',')]

        # 构建枢纽和桥梁列表
        hub_names = sorted(zip(card_names, deg_stats["degrees"]), key=lambda x: x[1], reverse=True)[:15]
        bridge_names = sorted(zip(card_names, betweenness), key=lambda x: x[1], reverse=True)[:15]

        index = {
            "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "card_count": n,
            "total_edges": edges,
            "avg_shortest_path": round(avg_path, 2),
            "diameter": diameter,
            "nodes": {
                card_names[i]: {
                    "degree": deg_stats["degrees"][i],
                    "in_degree": in_degree[i],
                    "betweenness": round(betweenness[i], 6),
                    "out_links": [card_names[j] for j in adj[i]],
                    "is_cross_moc": card_names[i] in cross_moc,
                    "cross_mocs": cross_moc.get(card_names[i], []),
                    "is_articulation_point": i in ap_indices,
                }
                for i in range(n)
            },
            "dead_links": [{"from": src, "to": tgt} for src, tgt in dead_links],
            "top_hubs": [{"name": name, "degree": deg} for name, deg in hub_names],
            "top_bridges": [{"name": name, "betweenness": round(bc, 6)} for name, bc in bridge_names],
            "articulation_points": [{"name": card_names[i], "degree": deg_stats["degrees"][i]} for i in ap_indices],
        }
        if farthest_pair[0] < n and farthest_pair[1] < n:
            index["farthest_pair"] = {
                "from": card_names[farthest_pair[0]],
                "to": card_names[farthest_pair[1]],
                "distance": diameter,
            }

        index_path = os.path.abspath(args.output_index)
        os.makedirs(os.path.dirname(index_path), exist_ok=True)
        with open(index_path, 'w', encoding='utf-8') as f:
            json.dump(index, f, ensure_ascii=False, indent=2)
        print(f"📊 网络索引已写入: {index_path}", file=sys.stderr)

    elif not args.json:
        # 人类可读输出
        print(f"卡片总数: {n}")
        print(f"边数: {edges}")
        print(f"连通分量数: {len(components)}")
        print(f"最大分量: {len(components[0]) if components else 0} 张 ({len(components[0])/n*100:.1f}%)")
        print(f"孤立节点: {len(isolated)}")
        print(f"平均度: {deg_stats['avg']:.1f} (min={deg_stats['min']}, max={deg_stats['max']})")
        print(f"平均最短路径: {avg_path:.2f} 跳")
        print(f"中位数路径: {median_path} 跳")
        print(f"网络直径: {diameter} 跳")
        print(f"关节点: {len(ap_indices)}")
        print(f"死链: {len(dead_links)}")
        print(f"健康度: {grade}")
        if issues:
            for issue in issues:
                print(f"  {issue['level']} {issue['msg']}")


if __name__ == "__main__":
    main()
