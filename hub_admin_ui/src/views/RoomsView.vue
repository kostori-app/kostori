<script setup>
import { ref } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import AppModal from '../components/AppModal.vue';
import FormField from '../components/FormField.vue';
import StatusBadge from '../components/StatusBadge.vue';
import { api } from '../api.js';
import { run } from '../toast.js';

const props = defineProps({
  rooms: { type: Array, default: () => [] },
  lobbyId: { type: String, default: '' },
  loading: { type: Boolean, default: false },
});
const emit = defineEmits(['refresh']);

const messagesFor = ref(null); // { room, messages }
const sendTarget = ref(null);
const sendText = ref('');
const sendAsBot = ref(false);
const busy = ref(false);

// 大厅 ID 是服务端给的固定 UUID，不是空串
const isLobby = (r) => !!props.lobbyId && r.roomId === props.lobbyId;

function timeOf(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

async function openMessages(room) {
  const res = await run(() => api.roomMessages(room.roomId, 100));
  if (res.ok) {
    messagesFor.value = { room, messages: res.result.messages || [] };
  }
}

async function removeRoom(room) {
  if (!confirm(`确定删除房间「${room.roomName}」？\n房间内成员会被移回大厅，且无法撤销。`)) return;
  const res = await run(() => api.deleteRoom(room.roomId), {
    success: '房间已删除',
    failure: (e) => `删除失败：${e?.message}`,
  });
  if (res.ok) {
    emit('refresh');
  }
}

async function send() {
  if (!sendTarget.value || !sendText.value.trim()) return;
  busy.value = true;
  const res = await run(
    () => api.sendRoomMessage(sendTarget.value.roomId, sendText.value.trim(), sendAsBot.value),
    { success: '已发送', failure: (e) => `发送失败：${e?.message}` },
  );
  busy.value = false;
  if (res.ok) {
    sendText.value = '';
    sendTarget.value = null;
    emit('refresh');
  }
}
</script>

<template>
  <div class="stack">
    <Card
      title="房间"
      :subtitle="`共 ${rooms.length} 个 · 消息历史每房间保留最近 400 条`"
    >
      <template #actions>
        <AppButton size="sm" :busy="loading" @click="emit('refresh')">刷新</AppButton>
      </template>

      <div v-if="!rooms.length" class="empty">暂无房间</div>

      <div v-else class="grid">
        <article v-for="room in rooms" :key="room.roomId" class="room">
          <header class="room-head">
            <div class="grow">
              <h3 class="room-name truncate">
                {{ room.roomName }}
                <span v-if="isLobby(room)" class="tag">大厅</span>
                <span v-else-if="room.roomType === 'watch'" class="tag watch">一起看</span>
              </h3>
              <p class="faint mono truncate">{{ room.roomId }}</p>
            </div>
            <StatusBadge
              :status="room.isLocked ? 'busy' : 'online'"
              :label="room.isLocked ? '加密' : '公开'"
            />
          </header>

          <dl class="facts">
            <div><dt>成员</dt><dd>{{ room.participantCount }}</dd></div>
            <div><dt>消息</dt><dd>{{ room.messageCount }}</dd></div>
            <div v-if="room.maxParticipants">
              <dt>上限</dt>
              <dd :class="{ warn: room.isFull }">{{ room.maxParticipants }}</dd>
            </div>
            <div><dt>房主</dt><dd class="truncate">{{ room.ownerName || room.ownerUserId }}</dd></div>
          </dl>

          <p v-if="room.animeTitle" class="anime truncate">▸ {{ room.animeTitle }}</p>
          <p v-if="room.announcements?.length" class="ann truncate">
            ✎ {{ room.announcements.join(' / ') }}
          </p>

          <ul v-if="room.participants?.length" class="members">
            <li v-for="p in room.participants.slice(0, 8)" :key="p.userId" class="truncate">
              {{ p.name || p.userId }}<span v-if="p.isBot" class="bot">bot</span>
            </li>
            <li v-if="room.participants.length > 8" class="faint">
              +{{ room.participants.length - 8 }} 人
            </li>
          </ul>

          <footer class="row wrap">
            <AppButton size="sm" variant="ghost" @click="openMessages(room)">消息</AppButton>
            <AppButton size="sm" variant="ghost" @click="sendTarget = room">发言</AppButton>
            <AppButton
              size="sm"
              variant="danger"
              :disabled="isLobby(room)"
              :title="isLobby(room) ? '大厅不可删除' : ''"
              @click="removeRoom(room)"
            >
              删除
            </AppButton>
          </footer>
        </article>
      </div>
    </Card>

    <AppModal
      v-if="messagesFor"
      :title="`消息记录 · ${messagesFor.room.roomName}`"
      width="640px"
      @close="messagesFor = null"
    >
      <div v-if="!messagesFor.messages.length" class="empty">该房间暂无消息</div>
      <ul v-else class="msgs">
        <li v-for="m in messagesFor.messages" :key="m.time + m.text">
          <span class="who truncate">
            {{ m.sender }}<span v-if="m.isBot" class="bot">bot</span>
          </span>
          <span class="mono time">{{ timeOf(m.time) }}</span>
          <span class="text">{{ m.text }}</span>
        </li>
      </ul>
    </AppModal>

    <AppModal
      v-if="sendTarget"
      :title="`向「${sendTarget.roomName}」发言`"
      @close="sendTarget = null"
    >
      <div class="stack">
        <FormField
          v-model="sendText"
          type="textarea"
          label="内容"
          placeholder="支持纯文本"
        />
        <label class="check">
          <input v-model="sendAsBot" type="checkbox" />
          <span>以「Web 管理」机器人身份发送（留空则以 Server 身份发送）</span>
        </label>
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="sendTarget = null">取消</AppButton>
        <AppButton variant="primary" :busy="busy" :disabled="!sendText.trim()" @click="send">
          发送
        </AppButton>
      </template>
    </AppModal>
  </div>
</template>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(300px, 100%), 1fr));
  gap: 14px;
}

.room {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px;
  border-radius: var(--r);
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.02);
}

.room-head {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.room-name {
  font-size: 14px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 6px;
}

.tag {
  font-size: 10px;
  font-weight: 500;
  padding: 1px 6px;
  border-radius: 999px;
  background: var(--accent-soft);
  color: var(--accent);
  flex: none;
}
.tag.watch {
  background: var(--warn-soft);
  color: var(--warn);
}

.facts {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(64px, 1fr));
  gap: 8px;
}
.facts dt {
  font-size: 10px;
  color: var(--text-faint);
  text-transform: uppercase;
}
.facts dd {
  font-size: 13px;
  font-variant-numeric: tabular-nums;
  margin-top: 2px;
}
.warn {
  color: var(--warn);
}

.anime,
.ann {
  font-size: 12px;
  color: var(--text-muted);
}

.members {
  list-style: none;
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}
.members li {
  font-size: 11px;
  padding: 2px 7px;
  border-radius: 999px;
  background: var(--surface-3);
  color: var(--text-muted);
  max-width: 130px;
}

.bot {
  font-size: 9px;
  margin-left: 4px;
  color: var(--accent-2);
}

.msgs {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.msgs li {
  display: grid;
  grid-template-columns: 110px 46px minmax(0, 1fr);
  gap: 8px;
  padding: 5px 6px;
  border-radius: 5px;
  font-size: 13px;
}
.msgs li:nth-child(odd) {
  background: rgba(255, 255, 255, 0.02);
}
.who {
  color: var(--text-muted);
  font-size: 12px;
}
.time {
  color: var(--text-faint);
}
.text {
  word-break: break-word;
}

.check {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12.5px;
  color: var(--text-muted);
  cursor: pointer;
}
</style>
