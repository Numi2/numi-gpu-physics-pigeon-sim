# Feather layer ablation diagnosis

Shortening the CPU dorsal covert projections produced no convincing change.
To identify the source of the prominent regular rows and projections before
another design change, render the same overhead 100-frame accepted-state
sequence twice: with the CPU dorsal covert layer hidden and separately with the
Metal underwing covert layer hidden. This is diagnostic only; missing layers
are not a candidate final look. Preserve both outputs and source diff; remove
the diagnostic switches after capturing. The full videos continue using the
unchanged candidate 9 executable.

Result: hiding the CPU dorsal layer changes the overhead image relatively
little. Hiding the GPU underwing covert layer removes most of the conspicuous
regular feather rows, while leaving an overly smooth surface. This establishes
which renderer layer contributes the pattern in this view; it does not alone
prove that the layer is on the wrong anatomical side. Neither ablation is a
proposed final appearance. The full videos still use candidate 9.
