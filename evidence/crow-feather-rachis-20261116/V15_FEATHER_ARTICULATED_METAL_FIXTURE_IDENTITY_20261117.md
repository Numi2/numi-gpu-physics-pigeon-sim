# Current-model binding for the GPU reference

Research source commit `2eeee007e` makes the archived articulated-rod GPU regression compare each stored bird mass matrix and hand Jacobian against the live current v15 native model, within float input precision, before dispatch. All 12 focused native tests pass; `articulated-metal-kkt/LastTest.log` retains output. A deliberately stale mass in `crow-v15-stale-hand-negative-control.py` was rejected as expected; stdout and stderr are retained alongside it. This guards against stale fixture data passing silently after a model change.

The check does not add live articulated attachment support, nonlinear feather mechanics, aerodynamics or mission qualification.
