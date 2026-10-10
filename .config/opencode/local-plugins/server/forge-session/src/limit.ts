// How many forge requests run at once for a session with several targets.
export const CONCURRENCY = 4

// Maps `items` with at most `limit` calls of `fn` running at once, keeping
// the order of `items` in the results.
export async function mapLimit<T, R>(items: readonly T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const results = new Array<R>(items.length)
  let next = 0
  const worker = async () => {
    while (next < items.length) {
      const index = next++
      results[index] = await fn(items[index])
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker))
  return results
}
