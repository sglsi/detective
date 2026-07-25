const { getStorage } = require('C:/Users/sglsi/WorkBuddy/Claw/detective/backend/src/db/storage');
(async () => {
  const s = getStorage();
  const U = 'diag_clean', C = 'case_blood_letter';
  try {
    await s.upsertProgress(U, C, { status: 'in_progress', scenes_completed: ['s1','s2'], clues_found: 4, observation_stars: 2, reasoning_stars: 1, insight_stars: 3, badges_earned: ['b1'] });
    console.log('UPSERT1 (new) OK');
  } catch (e) { console.log('UPSERT1 ERR:', e.message); }
  try {
    await s.upsertProgress(U, C, { status: 'completed', scenes_completed: ['s1','s2','s3'], clues_found: 9, observation_stars: 5, reasoning_stars: 4, insight_stars: 5, badges_earned: ['b1','b2'] });
    console.log('UPSERT2 (existing UPDATE) OK');
  } catch (e) { console.log('UPSERT2 ERR:', e.message); }
  const r = await s.getProgress(U, C);
  console.log('GET PROGRESS:', JSON.stringify(r));
})();
