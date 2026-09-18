import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('助手档案合并：补齐本机缺失的 id，已有 id 保留本机版本', () async {
    final store = AssistantProfileStore.instance;
    await store.init();
    final localId = store.profiles.first.id;
    final before = store.profiles.length;

    await store.mergeData([
      {'id': localId, 'name': '远端改过的名字'},
      {'id': 'remote_1', 'name': '远端档案'},
    ]);

    expect(store.profiles.length, before + 1);
    // 本机已有档案不被远端覆盖
    expect(store.find(localId)!.name, isNot('远端改过的名字'));
    expect(store.find('remote_1')!.name, '远端档案');

    // 重复合并同一条不会重复添加
    await store.mergeData([
      {'id': 'remote_1', 'name': '远端档案'},
    ]);
    expect(store.profiles.length, before + 1);
  });

  test('长期记忆合并：同一档案取并集并去重', () async {
    final memory = AssistantMemoryStore.instance;
    await memory.mergeData({
      'p1': ['a', 'b'],
    });
    await memory.mergeData({
      'p1': ['b', 'c'],
      'p2': ['x'],
    });

    expect(await memory.entriesFor('p1'), ['a', 'b', 'c']);
    expect(await memory.entriesFor('p2'), ['x']);
    expect(memory.exportMergeData()['p1'], ['a', 'b', 'c']);
  });
}
