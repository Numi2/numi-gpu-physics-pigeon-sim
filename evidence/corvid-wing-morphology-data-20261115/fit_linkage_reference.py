#!/usr/bin/env python3
"""Quadratic reference fit with a chronological untouched portion of the same trial.
Does not set physical limits, infer 3-D joint axes, or establish a controller.
"""
from pathlib import Path
import csv,json,hashlib
import numpy as np
p=Path(__file__).resolve().parent;src=p/'crow_17_1L_linkage-angles.csv';rows=list(csv.DictReader(src.open(newline='')))
train=[r for r in rows if int(r['source_frame_1based'])<=350];test=[r for r in rows if int(r['source_frame_1based'])>=351];assert train and test
x=np.array([float(r['elbow_deg']) for r in train]);y=np.array([float(r['manus_deg']) for r in train]);xt=np.array([float(r['elbow_deg']) for r in test]);yt=np.array([float(r['manus_deg']) for r in test]);fit=np.polyfit(x,y,2);pred=np.polyval(fit,xt);err=pred-yt;base=np.full(len(test),np.mean(y));rms=lambda z:float(np.sqrt(np.mean(np.square(z))));base_rms=rms(base-yt);fit_rms=rms(err)
out={'input':src.name,'input_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'fit':'manus_deg = c2 * elbow_deg^2 + c1 * elbow_deg + c0','coefficients_c2_c1_c0':[float(z) for z in fit],'train_source_frames':'1-350','held_out_source_frames':'351-502','train_valid_count':len(train),'held_out_valid_count':len(test),'train_elbow_deg_range':[float(x.min()),float(x.max())],'held_out_elbow_deg_range':[float(xt.min()),float(xt.max())],'held_out_outside_training_count':int(np.count_nonzero((xt<x.min())|(xt>x.max()))),'held_out_rms_deg':fit_rms,'held_out_median_absolute_deg':float(np.median(np.abs(err))),'held_out_max_absolute_deg':float(np.max(np.abs(err))),'held_out_constant_baseline_rms_deg':base_rms,'rms_reduction_fraction':float(1-fit_rms/base_rms),'pre_registered_exploratory_pass':bool(fit_rms<15 and fit_rms<=.75*base_rms),'limitations':'One hand-manipulated specimen; time-contiguous held-out portion of same trial is not an independent animal. Raw anatomical measured-angle convention, no physics axes or hard joint limits.'}
(p/'linkage-reference-fit.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
