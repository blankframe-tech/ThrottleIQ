import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

const pending = atom({ plugin: 'docs-sync-band', key: 'pending' } as const, [])
const isDismissed = atom({ plugin: 'docs-sync-band', key: 'isDismissed' } as const, false)

// ThrottleIQ's handoff docs; editing one of these counts as "docs updated".
const DOC = /(^|\/)(features|HANDOFF_Document|issues_open|issues_fixed)\.md$/
// Not code: anything under DOCS/ or .claude/, any markdown, the pitch (off-limits).
const NOT_CODE = /(^|\/)(DOCS|\.claude|node_modules|build|out|dist)\/|\.(md|html|png|jpg|svg|json\.bak)$/

const PROMPT =
  'This session changed app behavior or project status. Update features.md, HANDOFF_Document.md, and/or ' +
  'issues_open.md / issues_fixed.md in DOCS/Handoff for agents and Todos/ to reflect it. ' +
  'Skip docs/pitch.md. If nothing doc-worthy changed, say so briefly.'

const touches = ['Edit', 'Write'] as const

export const register: Register = on => {
  for (const tool of touches) {
    on('tool.call', { tool }, async ($, e, next) => {
      const path = e.file_path
      if (DOC.test(path)) {
        await update($, pending, () => [])
      } else if (!NOT_CODE.test(path)) {
        await update($, pending, list => (list.includes(path) ? list : [...list, path]))
        await update($, isDismissed, () => false)
      }
      return next(e)
    }).catch(($, e, next) => next(e))
  }

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const files = await read($, pending)
    if (e.props.hasSurvey || e.props.isWorking || files.length === 0 || (await read($, isDismissed)))
      return next(e)
    if (!(await $.fs.exists('DOCS/Handoff for agents and Todos'))) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box>
        <Text bold>
          {files.length} code file{files.length === 1 ? '' : 's'} changed, Handoff docs not updated{' '}
        </Text>
        <Button key="update" label="Update docs" onPress={() => { void update($, pending, () => []); void $.prompt.submit({ text: PROMPT }) }} />
        <Button key="skip" label="Dismiss" onPress={() => update($, isDismissed, () => true)} />
      </Box>
    )
  })
}
