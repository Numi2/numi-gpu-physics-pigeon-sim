# Rachis energy matches beam scale; attachment reaction does not

The preregistered static-energy checks passed. At 9, 17 and 33 nodes, centered energy derivatives were 0.62905, 0.64276 and 0.64637 N respectively, converging toward the 0.64749 N beam reference. Zero-energy and sign-symmetry controls also passed. This checks the chosen uniform segment's stored energy and discretization; it is not an independent experimental prediction because measured E and I determine the input stiffness.

The pre-shaped reaction arm failed. All three CPU and all three batched Metal steps were accepted, but the final loaded midpoint reaction was only 0.00005662 N instead of the 0.64749 N reference. CPU and GPU closely agreed with one another, so their agreement alone cannot resolve the force discrepancy. The cause remains unproven; solver iteration criteria, transient equilibrium, and reaction-force accounting require separate checks. All node positions and velocities, inputs, statuses, logs, reactions, source and hashes are retained in `evidence/crow-feather-rachis-20261116/feather-rachis-energy-followup-20261116/`.

The source specimen is a carrion crow, the represented segment is uniform and isotropic, and this test lacks the remaining rachis, vanes, wing attachment and airflow. It does not qualify American-crow feather biomechanics, real folding, flight, landing or balance.
