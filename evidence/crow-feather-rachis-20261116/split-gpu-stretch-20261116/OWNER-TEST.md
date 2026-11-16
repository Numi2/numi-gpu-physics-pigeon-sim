# Owner regression test

Source branch `agent/crow-articulated-wing-20261116` at `20b8f43ab` adds a repeatable experimental CTest using runtime Metal compilation with fast math disabled and deterministic reference generation. The new test and six other targeted source-owner checks all passed; see `crow-split-owner-expanded-tests.log`. This commit only adds an arithmetic fixture and test. It does not route physical rod state or forces through the compensated method, and it is not a qualification of the crow mission.
