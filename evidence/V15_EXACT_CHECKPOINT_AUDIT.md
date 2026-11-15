# V15 visual checkpoint audit

The existing resident checkpoint implementation is present in the experimental host. It is admitted only for retinal tasks in the temporal-cone solver without a journey teacher, and the host only enables resident checkpoints for retinal task programs. The life checkpoint also requires a retinal observer and feeding/object-push configuration. The current v15 navigation tracker is not that observer, so these entry points do not save its complete state. No valid original 48-second v15 checkpoint has been established.

The visual tracker retains private object-track and masked-depth histories, `observationSequence`, `lastSensorSequence`, and cached rendering state. The sensor does not refresh on every control step; cached depth/identity/validity/camera data or geometric winners can feed observations between captures. Capturing only q/v, actions and an elapsed phase cannot establish continuation equivalence.

A prospective implementation needs an explicitly scoped v15 resident checkpoint, with all solver/contact/policy state, a transactionally restored visual tracker and last sensor image or winners, exact world family and policy identities, and fail-closed size/hash validation. Verify uninterrupted versus restored trajectories across both sampled and unsampled sensor boundaries and after contact, comparing observations, actions, q/v and contacts. Do not retrofit a purported exact checkpoint from the old replay; acquire a new one during an admitted run. This is an audit, not an implemented or verified checkpoint.

Inspected native source SHA-256:

- `artifacts/crow-v15-recorded-restart-20261114/MetalWorld-full-contact-observer.mm`: `63b605aaa5beff5bf39b202f336f9343787e414383508416d324ccbad72261cc`
- `artifacts/crow-v15-recorded-restart-20261114/c_api-toe-sensing-experiment.cpp`: `9e750aae3b34d256a20817611c3fe279fd5b4718c8fec1bd566429b30da248bb`
- `src/metal/MetalHybridRenderer.mm`: `10052bd144b65417eea091be60d2563320740ee9095155f3407d08a7128eb470`
- `include/metalrobo/MetalHybridRenderer.hpp`: `89bff74667cbd15cd5acd4c5e67fe74a39648944c3ae8a6bb35f0cad493e8ca7`
