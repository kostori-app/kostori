<script setup>
/**
 * 柱状图与热力图。手写 SVG 而不引图表库：只需要这两种图，
 * 而产物要塞进 APK，图表库动辄 150KB+。
 */
import { computed } from 'vue';

const props = defineProps({
  // bars: [{ label, value }]
  bars: { type: Array, default: () => [] },
  // cells: number[][]，外层索引对应行标签
  cells: { type: Array, default: () => [] },
  rowLabels: { type: Array, default: () => [] },
  max: { type: Number, default: 0 },
  height: { type: Number, default: 96 },
  color: { type: String, default: 'var(--accent)' },
});

const peak = computed(() => {
  if (props.max > 0) return props.max;
  const values = props.bars.map((b) => b.value);
  if (props.cells.length) {
    for (const row of props.cells) for (const v of row) values.push(v);
  }
  return Math.max(1, ...values);
});

/** 低 → 蓝，高 → 紫红 */
function heatColor(v) {
  if (!v) return 'rgba(255,255,255,0.035)';
  const t = Math.min(1, v / peak.value);
  return `rgba(${Math.round(91 + t * 138)}, ${Math.round(140 - t * 49)}, ${Math.round(255 - t * 8)}, ${0.18 + t * 0.72})`;
}
</script>

<template>
  <div class="chart">
    <div v-if="bars.length" class="bars" :style="{ height: `${height}px` }">
      <div
        v-for="(b, i) in bars"
        :key="i"
        class="bar-col"
        :title="`${b.label}: ${b.value}`"
      >
        <div class="bar-track">
          <div
            class="bar"
            :style="{
              height: `${Math.max(b.value > 0 ? 3 : 0, (b.value / peak) * 100)}%`,
              background: color,
            }"
          />
        </div>
        <span class="bar-label">{{ b.label }}</span>
      </div>
    </div>

    <div v-if="cells.length" class="heat">
      <div v-for="(row, r) in cells" :key="r" class="heat-row">
        <span v-if="rowLabels.length" class="heat-label">{{ rowLabels[r] ?? '' }}</span>
        <i
          v-for="(v, c) in row"
          :key="c"
          class="cell"
          :style="{ background: heatColor(v) }"
          :title="`${rowLabels[r] ?? r} ${String(c).padStart(2, '0')}:00 · ${v}`"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.chart {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.bars {
  display: flex;
  align-items: flex-end;
  gap: 3px;
}

.bar-col {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  height: 100%;
  gap: 4px;
}

.bar-track {
  flex: 1;
  display: flex;
  align-items: flex-end;
  min-height: 0;
}

.bar {
  width: 100%;
  border-radius: 3px 3px 0 0;
  transition: opacity 0.14s ease;
}
.bar-col:hover .bar {
  opacity: 0.75;
}

.bar-label {
  font-size: 9px;
  color: var(--text-faint);
  text-align: center;
  overflow: hidden;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}

.heat {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.heat-row {
  display: flex;
  align-items: center;
  gap: 2px;
}

.heat-label {
  width: 34px;
  flex: none;
  font-size: 9px;
  color: var(--text-faint);
  text-align: right;
  padding-right: 4px;
}

.cell {
  flex: 1;
  height: 9px;
  border-radius: 2px;
  min-width: 2px;
}
</style>
