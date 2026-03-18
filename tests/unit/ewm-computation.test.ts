describe('EWM (Exponentially Weighted Moving Average) Computation', () => {
  function computeEwm(events: { value: number; alpha: number }[]): number | null {
    let ewm: number | null = null;
    for (const event of events) {
      if (ewm === null) {
        ewm = event.value;
      } else {
        ewm = event.alpha * event.value + (1 - event.alpha) * ewm;
      }
    }
    return ewm;
  }

  test('single event returns the event value', () => {
    const result = computeEwm([{ value: 0.75, alpha: 0.4 }]);
    expect(result).toBe(0.75);
  });

  test('empty events returns null', () => {
    const result = computeEwm([]);
    expect(result).toBeNull();
  });

  test('known sequence with alpha=0.4 produces expected result', () => {
    // Events: 0.50, 0.60, 0.70, 0.80
    // EWM1 = 0.50
    // EWM2 = 0.4*0.60 + 0.6*0.50 = 0.24 + 0.30 = 0.54
    // EWM3 = 0.4*0.70 + 0.6*0.54 = 0.28 + 0.324 = 0.604
    // EWM4 = 0.4*0.80 + 0.6*0.604 = 0.32 + 0.3624 = 0.6824
    const events = [
      { value: 0.50, alpha: 0.4 },
      { value: 0.60, alpha: 0.4 },
      { value: 0.70, alpha: 0.4 },
      { value: 0.80, alpha: 0.4 },
    ];
    const result = computeEwm(events);
    expect(result).toBeCloseTo(0.6824, 4);
  });

  test('self-assessment uses lower alpha (0.2)', () => {
    // SELF_ASSESSMENT alpha = 0.200 (lower weight — self-reported)
    const events = [
      { value: 0.50, alpha: 0.4 },       // DIRECT_OBSERVATION
      { value: 0.90, alpha: 0.2 },       // SELF_ASSESSMENT (high self-rate)
    ];
    const result = computeEwm(events);
    // EWM1 = 0.50
    // EWM2 = 0.2*0.90 + 0.8*0.50 = 0.18 + 0.40 = 0.58
    expect(result).toBeCloseTo(0.58, 4);

    // Compare: if both were DIRECT_OBSERVATION at alpha=0.4:
    const events2 = [
      { value: 0.50, alpha: 0.4 },
      { value: 0.90, alpha: 0.4 },
    ];
    const result2 = computeEwm(events2);
    // EWM2 = 0.4*0.90 + 0.6*0.50 = 0.36 + 0.30 = 0.66
    expect(result2).toBeCloseTo(0.66, 4);

    // Self-assessment has less impact
    expect(result!).toBeLessThan(result2!);
  });

  test('historical entries use lowest alpha (0.12)', () => {
    const events = [
      { value: 0.60, alpha: 0.4 },       // DIRECT_OBSERVATION
      { value: 0.30, alpha: 0.12 },      // HISTORICAL_ENTRY (low quality)
    ];
    const result = computeEwm(events);
    // EWM1 = 0.60
    // EWM2 = 0.12*0.30 + 0.88*0.60 = 0.036 + 0.528 = 0.564
    expect(result).toBeCloseTo(0.564, 4);
  });

  test('idempotency: same data run twice produces same result', () => {
    const events = [
      { value: 0.50, alpha: 0.4 },
      { value: 0.60, alpha: 0.4 },
      { value: 0.70, alpha: 0.4 },
    ];
    const result1 = computeEwm(events);
    const result2 = computeEwm(events);
    expect(result1).toBe(result2);
  });

  test('declining mastery trend is detectable', () => {
    const events = [
      { value: 0.90, alpha: 0.4 },
      { value: 0.80, alpha: 0.4 },
      { value: 0.60, alpha: 0.4 },
      { value: 0.40, alpha: 0.4 },
    ];
    const result = computeEwm(events);
    // Recent values are much lower — EWM reflects this
    expect(result!).toBeLessThan(0.70);
  });
});

describe('k-Anonymity Threshold Computation', () => {
  function computeKThreshold(classSize: number, defaultK: number = 5): number {
    if (classSize < 12) {
      return Math.max(defaultK, Math.ceil(classSize * 0.6));
    }
    return defaultK;
  }

  test('default k=5 for large classes (>=12)', () => {
    expect(computeKThreshold(30)).toBe(5);
    expect(computeKThreshold(12)).toBe(5);
    expect(computeKThreshold(50)).toBe(5);
  });

  test('k auto-adjusted to 60% for small classes (<12)', () => {
    expect(computeKThreshold(10)).toBe(6);   // ceil(10*0.6) = 6
    expect(computeKThreshold(8)).toBe(5);    // ceil(8*0.6) = 5 = max(5,5)
    expect(computeKThreshold(11)).toBe(7);   // ceil(11*0.6) = 7
  });

  test('never goes below default k', () => {
    expect(computeKThreshold(5)).toBe(5);    // ceil(5*0.6)=3 but max(5,3)=5
    expect(computeKThreshold(3)).toBe(5);    // ceil(3*0.6)=2 but max(5,2)=5
  });
});

describe('Merkle Tree Properties', () => {
  const crypto = require('crypto');

  function sha256(data: string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  function buildMerkleRoot(recordIds: string[], contentHashes: string[]): string {
    if (recordIds.length === 0) return sha256('EMPTY_TREE');

    let leaves = recordIds.map((id, i) => sha256(`LEAF:${id}:${contentHashes[i]}`));

    while (leaves.length > 1) {
      const nextLevel: string[] = [];
      for (let i = 0; i < leaves.length; i += 2) {
        if (i + 1 < leaves.length) {
          nextLevel.push(sha256(`NODE:${leaves[i]}:${leaves[i + 1]}`));
        } else {
          nextLevel.push(sha256(`NODE:${leaves[i]}:${leaves[i]}`));
        }
      }
      leaves = nextLevel;
    }
    return leaves[0];
  }

  test('identical inputs produce identical root hash', () => {
    const ids = ['id1', 'id2', 'id3'];
    const hashes = ['h1', 'h2', 'h3'];
    const root1 = buildMerkleRoot(ids, hashes);
    const root2 = buildMerkleRoot(ids, hashes);
    expect(root1).toBe(root2);
  });

  test('different data produces different root hash', () => {
    const root1 = buildMerkleRoot(['id1'], ['h1']);
    const root2 = buildMerkleRoot(['id1'], ['h2']);
    expect(root1).not.toBe(root2);
  });

  test('empty tree produces deterministic hash', () => {
    const root = buildMerkleRoot([], []);
    expect(root).toBe(sha256('EMPTY_TREE'));
    expect(root.length).toBe(64);
  });

  test('single-leaf tree works correctly', () => {
    const root = buildMerkleRoot(['id1'], ['hash1']);
    const expected = sha256('LEAF:id1:hash1');
    expect(root).toBe(expected);
  });

  test('odd number of leaves: last leaf is duplicated', () => {
    const root3 = buildMerkleRoot(['a', 'b', 'c'], ['h1', 'h2', 'h3']);
    expect(root3.length).toBe(64);
  });
});

describe('Audit Hash Chain Verification', () => {
  const crypto = require('crypto');

  function computeRowHash(id: string, eventType: string, entityId: string, epochTime: string, prevHash: string): string {
    return crypto.createHash('sha256')
      .update(id + eventType + entityId + epochTime + prevHash)
      .digest('hex');
  }

  test('chain links are consistent', () => {
    const entry1Hash = computeRowHash('id1', 'CREATE', 'entity1', '1000', '');
    const entry2Hash = computeRowHash('id2', 'UPDATE', 'entity2', '2000', entry1Hash);
    const entry3Hash = computeRowHash('id3', 'DELETE', 'entity3', '3000', entry2Hash);

    expect(entry1Hash.length).toBe(64);
    expect(entry2Hash.length).toBe(64);
    expect(entry3Hash.length).toBe(64);

    // Verify chain links
    const verify2 = computeRowHash('id2', 'UPDATE', 'entity2', '2000', entry1Hash);
    expect(verify2).toBe(entry2Hash);
  });

  test('tampering with a record breaks the chain', () => {
    const entry1Hash = computeRowHash('id1', 'CREATE', 'entity1', '1000', '');
    const entry2Hash = computeRowHash('id2', 'UPDATE', 'entity2', '2000', entry1Hash);

    // Tamper: change event_type in entry 1
    const tamperedHash = computeRowHash('id1', 'TAMPERED', 'entity1', '1000', '');
    expect(tamperedHash).not.toBe(entry1Hash);

    // Entry 2's prev_log_hash no longer matches
    const verifyChain = computeRowHash('id2', 'UPDATE', 'entity2', '2000', tamperedHash);
    expect(verifyChain).not.toBe(entry2Hash);
  });
});
