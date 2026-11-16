from pathlib import Path
import json,struct,hashlib
import numpy as np
p=Path(__file__).resolve().parent
blob=(p/'articulated-kkt-input.bin').read_bytes()
print('base_input_sha256',hashlib.sha256(blob).hexdigest())
for pose in ('0.6','1.2','1.8'):
 live=json.loads((p/f'crow-pose-{pose}.json').read_text());assert live['nv']==46
 M=np.asarray(live['M']).reshape(46,46);J=np.asarray(live['J']).reshape(3,46); output=bytearray()
 for case in range(4):
  x=np.array(struct.unpack_from('<5624f',blob,case*22496),dtype=np.float32);A=x[:5329].reshape(73,73);jac=x[5402:5621].reshape(3,73);A[27:,27:]=M/(.000125**2);jac[:,27:]=-J;output.extend(struct.pack('<5624f',*x))
 out=p/f'input-pose-{pose}.bin';out.write_bytes(output);print(pose,hashlib.sha256(output).hexdigest())
