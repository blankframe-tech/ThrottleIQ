export type Pending = string[]

declare module 'claude-code' {
  interface PluginState {
    'docs-sync-band': { pending: Pending; isDismissed: boolean }
  }
}
