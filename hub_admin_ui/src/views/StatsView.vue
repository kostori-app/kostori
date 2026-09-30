<script setup>
import { computed } from 'vue';
import Card from '../components/Card.vue';
import StatTile from '../components/StatTile.vue';
import MiniChart from '../components/MiniChart.vue';
import AppButton from '../components/AppButton.vue';

const props = defineProps({
  stats: { type: Object, default: null },
  loading: { type: Boolean, default: false },
});
const emit = defineEmits(['refresh']);

const s = computed(() => props.stats?.summary || null);
const hourBars = computed(() =>
  (props.stats?.hourly || []).map((v, h) => ({ label: String(h), value: v })),
);
// 外层索引 0 = 最早一天
const heatRows = computed(() => props.stats?.heatmap || []);
const dayLabels = computed(() => {
  const daily = props.stats?.daily || [];
  return daily.map((_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (daily.length - 1 - i));
    return `${d.getMonth() + 1}/${d.getDate()}`;
  });
});
</script>

<template>
  <div class="stack">
    <Card title="消息统计" :subtitle="s ? `今日 ${s.today} 条 · 近一小时 ${s.lastHour} 条` : ''">
      <template #actions>
        <AppButton size="sm" :busy="loading" @click="emit('refresh')">刷新</AppButton>
      </template>

      <div v-if="!s" class="empty">正在统计…</div>

      <template v-else>
        <div class="tiles">
          <StatTile label="消息总数" :value="s.totalMessages" tone="accent" />
          <StatTile label="用户消息" :value="s.userMessages" />
          <StatTile label="机器人消息" :value="s.botMessages" />
          <StatTile
            label="一起看同步"
            :value="s.watchSyncMessages"
            sub="P2P 进度帧"
          />
        </div>

        <h3 class="section-title chart-title">24 小时分布</h3>
        <MiniChart :bars="hourBars" :height="88" />
      </template>
    </Card>

    <div class="two">
      <Card title="活跃排行" subtitle="按发送消息数">
        <div v-if="!stats?.topClients?.length" class="empty">暂无数据</div>
        <ol v-else class="rank">
          <li v-for="(c, i) in stats.topClients" :key="c.userId">
            <span class="idx">{{ i + 1 }}</span>
            <span class="grow truncate">{{ c.name || c.userId }}</span>
            <span class="mono count">{{ c.count }}</span>
          </li>
        </ol>
      </Card>

      <Card title="房间分布" subtitle="按消息数">
        <div v-if="!stats?.rooms?.length" class="empty">暂无数据</div>
        <ol v-else class="rank">
          <li v-for="r in stats.rooms" :key="r.name">
            <span class="idx type">{{ r.type === 'watch' ? '看' : '聊' }}</span>
            <span class="grow truncate">{{ r.name }}</span>
            <span class="faint">{{ r.participants }}人</span>
            <span class="mono count">{{ r.count }}</span>
          </li>
        </ol>
      </Card>
    </div>

    <Card title="近 7 日活跃热力" subtitle="颜色越亮表示该时段消息越多">
      <div v-if="!heatRows.length" class="empty">暂无数据</div>
      <MiniChart v-else :cells="heatRows" :row-labels="dayLabels" />
    </Card>
  </div>
</template>

<style scoped>
.tiles {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 12px;
}

.chart-title {
  margin: 20px 0 10px;
}

.two {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 16px;
}

.rank {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.rank li {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 6px 8px;
  border-radius: var(--r-sm);
  font-size: 13px;
}
.rank li:hover {
  background: rgba(255, 255, 255, 0.03);
}

.idx {
  width: 20px;
  height: 20px;
  flex: none;
  border-radius: 5px;
  display: grid;
  place-items: center;
  font-size: 11px;
  font-variant-numeric: tabular-nums;
  background: var(--surface-3);
  color: var(--text-muted);
}

.idx.type {
  background: var(--accent-soft);
  color: var(--accent);
}

.count {
  color: var(--text);
  font-variant-numeric: tabular-nums;
}
</style>
