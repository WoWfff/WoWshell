# Services Philosophy

Services own runtime data and external integrations.

Services should:
- avoid UI logic
- expose explicit reactive state
- remain isolated
- support graceful degradation
- tolerate missing runtime dependencies
