# Fixed-support rachis: coupled-world solver comparison

The preregistered one-step fixture was composed with the v15 body and a separate, world-fixed 25 mm rachis segment. Both modes reported successful dispatch and publication. This is not a feather attached to a wing and contains no aerodynamic vane, contact, gravity, or flight.

| Result | temporalCone | qualityNewton |
|---|---:|---:|
| maximum target displacement error | 32.91 µm | 0.213 µm |
| maximum free-node bending force | 0.000244 N | 0.000651 N |
| initial total elastic energy | 7.86247 µJ | 7.86247 µJ |
| final elastic + kinetic energy | 0.00888 µJ | 7.64161 µJ |
| preregistered result | **FAIL**: fixed supports | **PASS**: one-step narrow screen |

The diagnostics contain full saved positions, velocities, twist and twist rates. Both modes reported rod status code 0 and 242 iterations, which does not by itself establish convergence or physical accuracy. This run used the same world context in sequence; an independent-context, order-controlled repeat is needed before attributing the observed difference to solver mode. The single step does not establish time convergence, dynamic feather response, attachment to an articulated wing, or biological validity. The model is a uniform rod parameterized from one carrion crow, not an American crow feather.
