// @ts-ignore — vitest is invoked via npx, not a local dep
export default {
  test: {
    include: ['src/**/*.test.ts'],
    environment: 'node',
  },
}
