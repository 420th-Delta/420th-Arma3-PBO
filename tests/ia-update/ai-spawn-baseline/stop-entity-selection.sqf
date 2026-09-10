/* Frozen equivalent of the dec9787 Primary STOP ownership selector. */
params ['_state','_fn_exempt'];
(_state get 'entities') select {
	(_x getVariable ['QS_primaryPressure_entityEpoch',-1]) isEqualTo (_state get 'epoch') &&
	{!(_x call _fn_exempt)} && {((crew (vehicle _x)) findIf {_x call _fn_exempt}) < 0}
}
