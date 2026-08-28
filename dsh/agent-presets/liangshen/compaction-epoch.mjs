
























export function createEpochPromotion(promoteEvents, options = {}) {
  const includeSubagents = options.includeSubagents === true
  const promote = new Set(promoteEvents)
  
  const state = new Map()

  
  const scan = (session) => {
    let boundary = -1
    let promoted = false
    for (const event of session.events) {
      const seq = event.seq ?? 0
      if (event.type === 'compaction/end') {
        boundary = seq
        promoted = false
        continue
      }
      if (promote.has(event.type) && seq > boundary) promoted = true
    }
    const entry = { boundary, promoted }
    state.set(session.id, entry)
    return entry
  }

  return {
    






    status(agent) {
      if (agent === undefined) return { boundary: -1, promoted: true }
      const session = agent.session
      if (session === undefined) return { boundary: -1, promoted: true }


      if (!includeSubagents && (session.header?.delegationDepth ?? 0) > 0) return { boundary: -1, promoted: true }
      return state.get(session.id) ?? scan(session)
    },
    
    observe(session, event) {
      const entry = state.get(session.id)
      if (entry === undefined) return
      const seq = event.seq ?? 0
      if (event.type === 'compaction/end') {
        state.set(session.id, { boundary: seq, promoted: false })
        return
      }
      if (promote.has(event.type) && seq > entry.boundary && !entry.promoted) {
        state.set(session.id, { ...entry, promoted: true })
      }
    },
  }
}
