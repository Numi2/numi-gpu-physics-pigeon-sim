"""Illustrative parallel-axis lower bound; not a fitted crow mass distribution."""
import json, math
from pathlib import Path

wing_mass_kg=0.0357416905463
original_Ixx_kg_m2=3.68627297576e-05
v15_total_mass_kg=0.45006
raven_body_mass_kg=0.77838
raven_lengths_m=[0.1003,0.1144,0.1091]
scale=(v15_total_mass_kg/raven_body_mass_kg)**(1/3)
lengths=[x*scale for x in raven_lengths_m]
centers=[lengths[0]/2,lengths[0]+lengths[1]/2,lengths[0]+lengths[1]+lengths[2]/2]
mass=[wing_mass_kg/3]*3
mean=sum(m*x for m,x in zip(mass,centers))/sum(mass)
lower=sum(m*(x-mean)**2 for m,x in zip(mass,centers))
# Independent pairwise identity for the inertia of point masses about their center.
pairwise=sum(mass[i]*mass[j]*(centers[i]-centers[j])**2 for i in range(3) for j in range(i+1,3))/wing_mass_kg
assert math.isclose(lower,pairwise,rel_tol=1e-12)
result={'assumptions':'equal segment masses at midpoints along a straight wing; raven bone lengths cube-root scaled by body mass; point masses neglect all intrinsic moments', 'not_measured':'crow segment masses, centroids, specimen-specific scaling, three-dimensional joint locations', 'raven_bone_lengths_m':raven_lengths_m,'body_mass_scale':scale,'scaled_lengths_m':lengths,'segment_centers_m':centers,'point_mass_minimum_Ixx_kg_m2':lower,'independent_pairwise_Ixx_kg_m2':pairwise,'current_Ixx_kg_m2':original_Ixx_kg_m2,'lower_bound_to_current_ratio':lower/original_Ixx_kg_m2}
Path(__file__).with_name('segment-inertia-feasibility.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
