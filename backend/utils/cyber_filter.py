from __future__ import annotations

import logging
from pathlib import Path

logger = logging.getLogger("cyber-filter")

class CyberDFAFilter:
    def __init__(self) -> None:
        # 初始化根节点
        self.keyword_chains: dict = {}
        # 常见的分隔符（防止用户用空格或标点隔开敏感词，例如 "发.票"）
        self.delimiters = set([' ', '\t', '\n', '\r', ',', '.', '?', '!', '，', '。', '？', '！', '-', '_', '/'])
        
    def add_word(self, word: str) -> None:
        """将单个词组编织进 DFA 树"""
        word = word.strip().lower()
        if not word:
            return
        
        level = self.keyword_chains
        for i in range(len(word)):
            if word[i] in level:
                level = level[word[i]]
            else:
                if not isinstance(level, dict):
                    break
                level[word[i]] = {}
                level = level[word[i]]
        level['is_end'] = True

    def load_word_list(self, file_path: str | Path) -> None:
        """从你的 txt 文件加载黑名单"""
        path = Path(file_path)
        if not path.exists():
            logger.warning("[SYS_WARNING] word list %s not found", path)
            return
        with path.open('r', encoding='utf-8') as f:
            for line in f:
                entry = line.strip().strip(",")
                self.add_word(entry)

    def load_word_dir(self, dir_path: str | Path) -> None:
        path = Path(dir_path)
        if not path.exists() or not path.is_dir():
            logger.warning("[SYS_WARNING] word dir %s not found", path)
            return
        loaded = 0
        for txt in sorted(path.glob("*.txt")):
            self.load_word_list(txt)
            loaded += 1
        logger.info("[SYS_READY] loaded %s sensitive word files from %s", loaded, path)

    def check_and_replace(self, message: str, repl: str = "*") -> tuple[bool, str]:
        """
        拦截核心逻辑：
        返回 (是否包含违禁词_布尔值, 过滤后的安全文本)
        """
        message = str(message)
        normalized_message = message.lower()
        result = []
        is_dirty = False
        message_length = len(normalized_message)
        i = 0

        while i < message_length:
            char = normalized_message[i]
            # 跳过无意义的混淆字符
            if char in self.delimiters:
                result.append(message[i])
                i += 1
                continue
                
            level = self.keyword_chains
            step_ins = 0
            match_flag = False

            # 开始向下探测 Trie 树
            for j in range(i, message_length):
                next_char = normalized_message[j]
                if next_char in self.delimiters:
                    step_ins += 1
                    continue
                    
                if next_char in level:
                    step_ins += 1
                    level = level[next_char]
                    if level.get('is_end'):
                        match_flag = True
                        break
                else:
                    break

            if match_flag:
                is_dirty = True
                # 把探测到的长度全部替换成星号或乱码
                result.append(repl * step_ins)
                i += step_ins
            else:
                result.append(message[i])
                i += 1

        return is_dirty, "".join(result)

# ==========================================
# 🔌 单例模式：在 FastAPI 启动时只加载一次
# ==========================================
dfa_filter = CyberDFAFilter()
_WORD_DIR = Path(__file__).resolve().parent.parent / "sensitive-stop-words"
dfa_filter.load_word_dir(_WORD_DIR)