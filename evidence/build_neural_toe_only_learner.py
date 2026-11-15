from pathlib import Path
import hashlib,json,shutil
r=Path('/Users/n/Developer/numi-crow-rl-20261107');b=r/'build/crow-v15-recorded-restart-20261114';a=r/'artifacts/crow-v15-recorded-restart-20261114';src=b/'neural-toe-python';dst=b/'neural-toe-only-python';assert not dst.exists();shutil.copytree(src,dst,ignore=shutil.ignore_patterns('__pycache__','*.pyc'));p=dst/'metalrobo/mlx_policy_learning.py';s=p.read_text();needle='''        _, actor_gradient_norm = optim.clip_grad_norm(
''';assert s.count(needle)==1
patch='''        # Experimental isolation: retain the learned leg actor exactly;
        # only the four toe output rows may change. Critic remains trainable.
        flat_gradients = list(tree_flatten(gradients))
        output_layers = [
            (int(name.split(".")[2]), name.rsplit(".", 1)[0])
            for name, grad in flat_gradients
            if name.startswith("actor.layers.") and name.endswith(".weight")
            and grad.ndim == 2
        ]
        if not output_layers:
            raise ValueError("missing actor output layer")
        output_layer = max(output_layers)[1]
        isolated = []
        for name, grad in flat_gradients:
            if name == output_layer + ".weight":
                mask = mx.array([1.0 if 4 <= i < 8 else 0.0 for i in range(grad.shape[0])], dtype=grad.dtype)[:, None]
                grad = grad * mask
            elif name == output_layer + ".bias":
                mask = mx.array([1.0 if 4 <= i < 8 else 0.0 for i in range(grad.shape[0])], dtype=grad.dtype)
                grad = grad * mask
            elif name.startswith("actor.") or name == "log_standard_deviation":
                grad = mx.zeros_like(grad)
            isolated.append((name, grad))
        gradients = tree_unflatten(isolated)
'''
s=s.replace(needle,patch+needle);p.write_text(s);(a/'neural-toe-only-build.json').write_text(json.dumps({'source_sha256':hashlib.sha256((src/'metalrobo/mlx_policy_learning.py').read_bytes()).hexdigest(),'learner_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'scope':'only toe output rows 4-7 updated; actor trunk, other rows, all logstd fixed; critic trainable'},indent=2)+'\n');print('toe-only learner built')
