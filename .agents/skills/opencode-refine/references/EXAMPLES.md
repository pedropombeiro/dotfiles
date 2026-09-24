# Examples Reference

Use this reference for concrete `opencode run` testing patterns.

## Fast Loop

```bash
# Edit the config, skill, or prompt
opencode run --standalone 'your test prompt'
opencode run --standalone -m gitlab/duo-chat-gpt-5-4-nano 'your test prompt'
```

## Debug Config Loading

Server logs only reach `--print-logs` with `--standalone`.

```bash
opencode run --standalone --print-logs 'your test prompt' 2>debug.log
```

Review debug logs for:

- loaded config files
- applied permissions
- tool registry startup
- bash executions and exit codes

## Test Project-Specific Config

```bash
(cd ~/workspace/my-project && opencode run --standalone 'run git status')
```

## Multi-Turn Refinement

```bash
opencode run 'I am working in directory $TMPDIR/myproject. Run git init there.'
opencode run --continue 'now create a README.md and commit it'
opencode run --continue 'run git log and show me what happened'
```

## JSON Event Stream

```bash
opencode run --format json 'what is 2+2?'
opencode run --format json 'run date'
```
