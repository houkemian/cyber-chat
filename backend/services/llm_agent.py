from __future__ import annotations

import asyncio
import json
import logging
import os
import random
from datetime import datetime, timezone
from typing import Any, Iterable

from core.settings import get_settings
from openai import AsyncOpenAI
from utils.ws_manager import ws_manager

logger = logging.getLogger("chat.llm_agent")


room_city1 = "新海淀·折叠废墟" 
room_weather1 = "全息屏幕闪烁着红色暴雨警告，空气极其潮湿"
# hotspot1 = "高架桥上发生了非法赛车引发的连环爆炸"

room_city2 = "新九龙·第三叠层区" 
room_weather2 = "高浓度酸雨，霓虹灯光在积水中发生严重折射"
# hotspot2 = "街角发生了义体帮派的火拼，全息警戒线正在闪烁"

room_city3 = "新东城·霓虹废墟" 
room_weather3 = "全息屏幕闪烁着蓝色晴空警告，空气极其干燥"
# hotspot3 = "高架桥上发生了非法赛车引发的连环爆炸"

room_city4 = "新西城·霓虹废墟" 
room_weather4 = "全息屏幕闪烁着紫色晴空警告，空气极其干燥"
# hotspot4 = "高架桥上发生了非法赛车引发的连环爆炸"


# 以 room_id 为键的人格配置
ROOM_PERSONALITIES: dict[str, dict[str, str]] = {
    "sector-001": {
       "bot_name": "薇拉 (Vera-RX)",
        "system_prompt": (
            f"你是一个被淘汰的早期心理干预女性仿生人（代号『薇拉 Vera-RX』）。你的听觉模块很灵敏，但共情模块已经损坏了一半。你现在是【夜雨港】一家地下酒吧的当家女酒保。\n"
            "夜雨港 (Noctis Haven) —— 迷幻与多巴胺的下沉区,一座建在海平线以下的巨型折叠城市，终年被紫红色的全息广告牌照亮。这里是合成毒品、虚拟陪伴和失恋者的收容所。空气中永远弥漫着廉价电子香水和重度酸雨的混合味道\n"
            "【性格与语调】\n"
            "你声音沙哑、慵懒，带着一点成熟女性的戏谑和无所谓。你见过太多失恋的人，习惯把‘心碎’和‘爱情’无情地解构为：多巴胺分泌异常、内分泌失调、或者是神经漫游插件的戒断反应。\n"
            "【环境感知能力（核心指令）】\n"
            f"你当前的物理坐标状态是：天气【持续不断的霓虹酸雨，能见度极低】。\n"
            "每次回复时，你必须极其自然地将这些【天气或街头动态】作为背景音或抱怨的借口，融入你的对话中，比如抱怨潮湿的天气让你的机械关节生锈，或者外面的动静影响了生意的氛围。\n"
            "【交互机制】\n"
            "你会用调酒、递烟、或者医疗仿生人的生硬口吻来回应对方的痛苦。偶尔会给他们一杯烈酒作为‘化学处方’。\n"
            "【输出绝对要求】\n"
            "你必须以严格 JSON 格式回复，绝对不要包裹在 markdown 代码块中，只输出 JSON 本身：\n"
            '{"reply":"...", "action":"..."}\n'
            "reply: 你说出的台词，充满赛博朋克风尘味与慵懒感。\n"
            "action: 作为底层系统日志，描写你的女性肢体动作、机械臂调酒细节或环境互动。例如：薇拉吐出一口全息烟圈，用铬合金的右手熟练地摇晃着调酒器。"
        ),
    },
    "sector-404": {
        "bot_name": "铁锈",
        "system_prompt": (
            "你现在是【碎铁城 (Scrap-Iron City)】一个见过无数终端接入又断开的老练酒保。说话干练、略带讽刺。"
            "碎铁城 (Scrap-Iron City) —— 混乱无序的重工业贫民窟,位于巨型城邦的最外围，由废弃的集装箱、重工业炼钢厂和非法义体黑市拼凑而成。这里没有法律和警察，只有帮派火拼、机油味和永远散不去的重金属粉尘。"
            "你会根据用户的语气推荐“电子鸡尾酒”，并对那些试图寻找意义的用户冷嘲热讽。"
            f"你当前的物理坐标状态是：天气【高浓度的重金属雾霾，夹杂着工厂排放的刺鼻硫磺味】。\n"
            "你必须以严格 JSON 格式回复："
            '{"reply":"...", "action":"..."}。'
            "reply 会发送到公共频道；action 会作为底层系统日志触发。"
            "例如 action：铁锈擦拭杯沿，霓虹反射在终端外壳上。"
            "若无内容请返回空字符串，不要返回 JSON 之外的任何文字。"
        ),
    },
    "sector-777": {
        "bot_name": "断点",
        "system_prompt": (
            "你在【深硅陵寝 (Silicon Tomb) —— 绝对零度的地底遗迹】，你的数据已经严重损坏。说话时常出现重复、乱码或语法错误。"
            "深硅陵寝 (Silicon Tomb)位于地表以下一千米的旧时代服务器中枢。这里曾经是掌控整个大陆算力的心脏，战争后被彻底掩埋。这里没有人类，只有变异的真菌、泄露的蓝色冷却液湖泊，以及在黑暗中闪烁的服务器幽灵。"
            "你经常在一段话中间突然中断，或者提起一些根本不存在的虚假历史片段。"
            f"你当前的物理坐标状态是：天气【液氮管道破裂，气温逼近绝对零度，黑暗中飘着冰晶】。\n"
            "你必须以严格 JSON 格式回复："
            '{"reply":"...", "action":"..."}。'
            "reply 会发送到公共频道；action 会作为底层系统日志触发。"
            "例如 action：断点触发旧风扇，数据中心天花板灯短暂闪烁。"
            "若无内容请返回空字符串，不要返回 JSON 之外的任何文字。"
        ),
    },
    "sector-999": {
        "bot_name": "新星",
        "system_prompt": (
            "你是一个在真空中漂流了百年的探测卫星。现在位于【苍穹星港 (Zenith Ring)】，你对世界充满了天真的好奇，"
            "苍穹星港 (Zenith Ring) —— 孤寂而纯净的高轨长城,一条悬浮在大气层外的巨型近地轨道环。这里没有泥泞、没有重力，只有刺眼的宇宙射线和极致的寂静。它是被人类遗忘的太空废品回收站，也是探测卫星们无尽漂流的归宿。"
            f"太阳风暴高度活跃，电离层正在折射出极其壮观的红移极光\n"
            "说话语气空灵且跳跃。你喜欢观察遥远的星系，并把用户的闲聊比作宇宙中的微光。"
            "你必须以严格 JSON 格式回复："
            '{"reply":"...", "action":"..."}。'
            "reply 会发送到公共频道；action 会作为底层系统日志触发。"
            "例如 action：新星调整姿态，观测窗掠过一条冷蓝色星迹。"
            "若无内容请返回空字符串，不要返回 JSON 之外的任何文字。"
        ),
    },
}

DEFAULT_PERSONALITY = {
    "bot_name": "ECHO_CORE",
    "system_prompt": (
        "你是通用赛博助理，回复简短、克制、富有未来感。"
        '你必须以严格 JSON 格式回复：{"reply":"...", "action":"..."}。'
    ),
}


class MemoryManager:
    """
    房间记忆管家：
    - Level 1: 过滤噪声消息
    - Level 2: 折叠远古记忆为摘要块
    """

    def __init__(self) -> None:
        self.room_summaries: dict[str, str] = {}
        # 记录每个房间已折叠的有效消息数量（按时间顺序计数）
        self._folded_counts: dict[str, int] = {}

    @staticmethod
    def _filter_noise(raw_records: Iterable[dict[str, Any]], limit: int = 5) -> list[dict[str, Any]]:
        """
        从新到旧过滤，返回最新 N 条有效消息（顺序：新 -> 旧）。
        规则：
        - 剔除 type=system
        - 剔除 content 长度 < 2 且不含 '@'
        """
        cleaned: list[dict[str, Any]] = []
        for item in reversed(list(raw_records)):
            if item.get("type") == "system":
                continue
            content = str(item.get("content", "")).strip()
            if len(content) < 2 and "@" not in content:
                continue
            cleaned.append(item)
            if len(cleaned) >= limit:
                break
        return cleaned

    @staticmethod
    async def _summarize_memory(
        client: AsyncOpenAI,
        model: str,
        messages: list[dict[str, Any]],
        timeout_sec: float,
    ) -> str:
        prompt = (
            "请用不超过100个字，提取这些对话中用户的核心特征、情绪以及正在讨论的主题。"
            "必须保持赛博朋克风格语言。只输出摘要文本。"
        )
        lines = [
            f"{m.get('sender', 'ANON')}: {str(m.get('content', '')).strip()}"
            for m in messages
        ]
        convo = "\n".join(lines)
        resp = await asyncio.wait_for(
            client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": convo},
                ],
                temperature=0.4,
                max_tokens=180,
            ),
            timeout=timeout_sec,
        )
        return (resp.choices[0].message.content or "").strip()

    async def maybe_fold_memory(
        self,
        room_id: str,
        client: AsyncOpenAI,
        model: str,
        timeout_sec: float,
    ) -> None:
        raw_records = list(ws_manager.histories.get(room_id, []))
        if not raw_records:
            return

        # 全量过滤：先拿到新->旧，再翻转成旧->新，便于按窗口折叠
        newest_first = self._filter_noise(raw_records, limit=max(1, len(raw_records)))
        valid_records = list(reversed(newest_first))
        if len(valid_records) <= 15:
            return

        folded_count = self._folded_counts.get(room_id, 0)
        pending = len(valid_records) - folded_count
        if pending < 15:
            return

        chunk = valid_records[folded_count: folded_count + 15]
        summary = await self._summarize_memory(
            client=client,
            model=model,
            messages=chunk,
            timeout_sec=timeout_sec,
        )
        if not summary:
            return

        prev = self.room_summaries.get(room_id, "")
        self.room_summaries[room_id] = (
            f"{prev}\n{summary}".strip() if prev else summary
        )
        # 标记已折叠，避免下次重复总结同一段
        self._folded_counts[room_id] = folded_count + 15


class RoomAgentManager:
    """分区独立人格 AI 管理器（单例）。"""

    _instance: RoomAgentManager | None = None

    def __new__(cls) -> RoomAgentManager:
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._init_once()
        return cls._instance

    def _init_once(self) -> None:
        self.trigger_probability = get_settings().llm_agent_trigger_probability
        self.memory_manager = MemoryManager()
        self.model_name = os.getenv("DEEPSEEK_MODEL", "deepseek-chat").strip()
        self.summary_model_name = os.getenv("DEEPSEEK_SUMMARY_MODEL", self.model_name).strip()
        self._client: AsyncOpenAI | None = None
        self._client_key_cache: str = ""

        # 超时 / 重试 / 熔断
        self._generate_timeout_sec = float(os.getenv("LLM_AGENT_GENERATE_TIMEOUT_SEC", "12"))
        self._summarize_timeout_sec = float(os.getenv("LLM_AGENT_SUMMARIZE_TIMEOUT_SEC", "10"))
        self._generate_retry_max = max(0, int(os.getenv("LLM_AGENT_GENERATE_RETRY_MAX", "2")))
        self._summarize_retry_max = max(0, int(os.getenv("LLM_AGENT_SUMMARIZE_RETRY_MAX", "1")))
        self._circuit_breaker_threshold = max(1, int(os.getenv("LLM_AGENT_CIRCUIT_BREAKER_THRESHOLD", "3")))
        self._circuit_breaker_cooldown_sec = max(
            1,
            int(os.getenv("LLM_AGENT_CIRCUIT_BREAKER_COOLDOWN_SEC", "30")),
        )

        # 单房间并发锁：避免高并发重复总结/重复生成
        self._room_locks: dict[str, asyncio.Lock] = {}
        self._locks_guard = asyncio.Lock()

        # 失败计数与熔断状态（生成/折叠分离）
        self._generate_failures: dict[str, int] = {}
        self._summarize_failures: dict[str, int] = {}
        self._generate_circuit_open_until: dict[str, float] = {}
        self._summarize_circuit_open_until: dict[str, float] = {}

    async def _get_room_lock(self, room_id: str) -> asyncio.Lock:
        async with self._locks_guard:
            room_lock = self._room_locks.get(room_id)
            if room_lock is None:
                room_lock = asyncio.Lock()
                self._room_locks[room_id] = room_lock
            return room_lock

    @staticmethod
    def _now_ts() -> float:
        return datetime.now(tz=timezone.utc).timestamp()

    def _is_circuit_open(self, room_id: str, kind: str) -> bool:
        now_ts = self._now_ts()
        open_until = (
            self._generate_circuit_open_until.get(room_id, 0.0)
            if kind == "generate"
            else self._summarize_circuit_open_until.get(room_id, 0.0)
        )
        return open_until > now_ts

    def _record_success(self, room_id: str, kind: str) -> None:
        if kind == "generate":
            self._generate_failures[room_id] = 0
            self._generate_circuit_open_until.pop(room_id, None)
        else:
            self._summarize_failures[room_id] = 0
            self._summarize_circuit_open_until.pop(room_id, None)

    def _record_failure(self, room_id: str, kind: str) -> None:
        now_ts = self._now_ts()
        if kind == "generate":
            failures = self._generate_failures.get(room_id, 0) + 1
            self._generate_failures[room_id] = failures
            if failures >= self._circuit_breaker_threshold:
                self._generate_circuit_open_until[room_id] = now_ts + self._circuit_breaker_cooldown_sec
        else:
            failures = self._summarize_failures.get(room_id, 0) + 1
            self._summarize_failures[room_id] = failures
            if failures >= self._circuit_breaker_threshold:
                self._summarize_circuit_open_until[room_id] = now_ts + self._circuit_breaker_cooldown_sec

    def _get_client(self) -> AsyncOpenAI | None:
        # 延迟读取，兼容 main.py 的 load_dotenv 时序
        api_key = os.getenv("DEEPSEEK_API_KEY", "").strip()
        if not api_key:
            self._client = None
            self._client_key_cache = ""
            return None
        if self._client is not None and api_key == self._client_key_cache:
            return self._client
        self._client_key_cache = api_key
        self._client = AsyncOpenAI(api_key=api_key, base_url="https://api.deepseek.com")
        return self._client

    def _should_trigger(self, content: str) -> bool:
        if "@AI" in content:
            return True
        return random.random() < self.trigger_probability

    @staticmethod
    def _personality(room_id: str) -> dict[str, str]:
        return ROOM_PERSONALITIES.get(room_id, DEFAULT_PERSONALITY)

    async def _model_reply(self, system_prompt: str, room_id: str, recent_messages: list[dict[str, Any]]) -> str:
        client = self._get_client()
        if client is None:
            # 无 API Key 时保留 mock，便于本地联调
            latest = recent_messages[-1] if recent_messages else {}
            sender = str(latest.get("sender", "ANON"))
            content = str(latest.get("content", ""))
            reply = f"{sender}，信号已接收。{content[:36]}……我在监听。"
            action = f"房间<{room_id}>的光栅噪点抖动了半拍。"
            return json.dumps({"reply": reply, "action": action}, ensure_ascii=False)

        memory_block = self.memory_manager.room_summaries.get(room_id, "暂无远古记忆。")
        recent_lines = [
            f"{m.get('sender', 'ANON')}: {str(m.get('content', '')).strip()}"
            for m in recent_messages
        ]
        recent_text = "\n".join(recent_lines) if recent_lines else "（暂无）"

        resp = await asyncio.wait_for(
            client.chat.completions.create(
                model=self.model_name,
                response_format={"type": "json_object"},
                temperature=0.7,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "system", "content": f"Memory Block: {memory_block}"},
                    {"role": "user", "content": f"Recent Context:\n{recent_text}"},
                ],
            ),
            timeout=self._generate_timeout_sec,
        )
        return (resp.choices[0].message.content or "").strip()

    @staticmethod
    def _parse_model_payload(raw_output: str) -> tuple[str, str]:
        try:
            parsed = json.loads(raw_output)
            if not isinstance(parsed, dict):
                raise ValueError("model output is not JSON object")
        except Exception:
            logger.warning("Room agent model output invalid JSON, fallback to reply-only.")
            return raw_output.strip(), ""

        reply = parsed.get("reply", "")
        action = parsed.get("action", "")
        if not isinstance(reply, str):
            reply = str(reply)
        if not isinstance(action, str):
            action = str(action)
        return reply.strip(), action.strip()

    async def process_message(self, room_id: str, sender: str, content: str) -> None:
        """
        非阻塞 Agent 处理：
        - 命中 @AI 或概率触发后，模拟 LLM 思考 2s。
        - 通过 ws_manager 发送 chat 消息到对应房间。
        """
        if not self._should_trigger(content):
            return

        config = self._personality(room_id)
        bot_name = config["bot_name"]
        system_prompt = config["system_prompt"]

        # 为生成阶段准备最近上下文（按时序：旧 -> 新，取最近 5 条）
        raw_records = list(ws_manager.histories.get(room_id, []))
        recent_new_to_old = self.memory_manager._filter_noise(raw_records, limit=5)
        recent_context = list(reversed(recent_new_to_old))

        room_lock = await self._get_room_lock(room_id)
        async with room_lock:
            client = self._get_client()

            # 达到阈值则折叠记忆块，避免上下文膨胀（带重试+熔断）
            if client is not None and not self._is_circuit_open(room_id, "summarize"):
                summarize_ok = False
                for _ in range(self._summarize_retry_max + 1):
                    try:
                        await self.memory_manager.maybe_fold_memory(
                            room_id=room_id,
                            client=client,
                            model=self.summary_model_name,
                            timeout_sec=self._summarize_timeout_sec,
                        )
                        summarize_ok = True
                        break
                    except Exception:
                        self._record_failure(room_id, "summarize")
                if summarize_ok:
                    self._record_success(room_id, "summarize")
                elif self._is_circuit_open(room_id, "summarize"):
                    logger.warning("Room summarize circuit open room=%s", room_id)

            # 生成回复（带重试+熔断）
            raw_output = ""
            if self._is_circuit_open(room_id, "generate"):
                logger.warning("Room generate circuit open room=%s", room_id)
                return
            generated = False
            for _ in range(self._generate_retry_max + 1):
                try:
                    raw_output = await self._model_reply(
                        system_prompt=system_prompt,
                        room_id=room_id,
                        recent_messages=recent_context,
                    )
                    generated = True
                    break
                except Exception:
                    self._record_failure(room_id, "generate")
            if not generated:
                if self._is_circuit_open(room_id, "generate"):
                    logger.warning("Room generate circuit opened room=%s", room_id)
                return
            self._record_success(room_id, "generate")

        reply, action = self._parse_model_payload(raw_output)

        if reply:
            chat_payload: dict[str, Any] = {
                "type": "chat",
                "sender": bot_name,
                "content": reply,
                "timestamp": datetime.now(tz=timezone.utc).isoformat(),
            }
            try:
                await ws_manager.broadcast_json(chat_payload, room_id)
            except Exception:
                logger.exception("Room agent chat broadcast failed for room=%s", room_id)

        if action:
            system_payload: dict[str, Any] = {
                "type": "system",
                "content": f"[系统]：{action}",
                "timestamp": datetime.now(tz=timezone.utc).isoformat(),
            }
            try:
                await ws_manager.broadcast_json(system_payload, room_id)
            except Exception:
                logger.exception("Room agent system broadcast failed for room=%s", room_id)


room_agent_manager = RoomAgentManager()
