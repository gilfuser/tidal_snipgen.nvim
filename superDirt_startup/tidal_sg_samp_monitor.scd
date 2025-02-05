q = q ? ();
q.numOrbs = q.numOrbs ? 16; // escolher quantas orbits serão usadas em Ndefs
q.orbits_out_chans = Array.fill ( q.numOrbs, { |i| 2 + (i * 2) } );

Task {
  wait(0.05);
  q.monitor = ~dirt.orbits[15];
  Ndef( \monitor ).ar(2);
  wait(0.05);
  q[ \monitor ].outBus = Ndef( \orbit ).bus;
  wait(0.05);
  Ndef( \monitor ).play( q.orbits_out_chans.last - 1);
  wait(0.05);
  Ndef( \monitor ).vol_(0.5);
  wait(0.05);
  {
    q.mon_gui = Ndef(\monitor).gui;
    // ProxyMeter.addMixer(q.mon_gui);
  }.defer(1);

}.play;
