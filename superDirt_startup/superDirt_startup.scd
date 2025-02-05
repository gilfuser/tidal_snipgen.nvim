q = q ? ();

// NOTE: tidal_snipgen depends on this for logging fx and synths:
q.previous_synthDescs = q.previous_synthDescs ? SynthDescLib.global.synthDescs.keys;
q.previous_synthDescs.collect{|x| x.postln};
q.numOrbs = q.numOrbs ? 16; // escolher quantas orbits serão usadas em Ndefs

if ( currentEnvironment.class == ProxySpace ) { topEnvironment.push };

fork{

  0.2.wait;
  if (~dirt != nil ) {
    ~dirt.stop; ~dirt.freeAllSoundFiles; ~dirt.free; ~dirt = nil; "reseting ~dirt".postln
  };
  ~dirt = SuperDirt(2, s);
  q.orbits_out_chans = Array.fill ( q.numOrbs, { |i| 2 + (i * 2) } );
  ~dirt.start( 57120, q.orbits_out_chans, NetAddr("0.0.0.0") );
  0.2.wait;

  ">>>>>> check point from SuperDirt Startup <<<<<<".postln;

  // "~/SuperCollider/instruments/01b_my_tidal_instruments.scd".standardizePath.load;
  0.2.wait;

  (
    Task {
    ( q.numOrbs ).do { |i|
      var j = i + 1;
      var orbit = format("orb%",j).asSymbol;
      q[ orbit ] = ~dirt.orbits[i];
      wait(0.05);
      Ndef( orbit ).ar(2);
      wait(0.05);
      Ndef( orbit ).proxyspace.quant_(1).clock_(t);
      wait(0.05);
      q[ orbit ].outBus = Ndef( orbit ).bus;
      wait(0.05);
      Ndef( orbit ).play( q.orbits_out_chans[i] /* + 2 */ );
      wait(0.05);
      Ndef( orbit ).vol_(0.5);
      wait(0.05);
    };
    Ndef( \allOrbs, {
      Limiter.ar(
      ( Ndef(\orb1).ar * \amp1.kr(1, spec:\ampx4.asSpec) ) +
        ( Ndef(\orb2).ar * \amp2.kr(1, spec:\ampx4.asSpec) ) +
        ( Ndef(\orb3).ar * \amp3.kr(1, spec:\ampx4.asSpec) ) +
        ( Ndef(\orb4).ar * \amp4.kr(1, spec:\ampx4.asSpec) ) +
        ( Ndef(\orb5).ar * \amp5.kr(1, spec:\ampx4.asSpec) ) +
        ( Ndef(\orb6).ar * \amp6.kr(1, spec:\ampx4.asSpec) ) +
        ( Ndef(\orb7).ar * \amp7.kr(1, spec:\ampx4.asSpec) ) +
        ( Ndef(\orb8).ar * \amp8.kr(1, spec:\ampx4.asSpec) )
      );
    }).play.vol_(0.5);
  }.play;
  );
// FIX: *** ERROR: SynthDef dirt_global_wah2 not found
// "~/SuperCollider/FX/myTidalFx.scd".standardizePath.load;
  wait(8);
"tidal_snipgen.scd".loadRelative;
"tidal_sg_samp_monitor.scd".loadRelative;
};
