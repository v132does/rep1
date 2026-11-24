create index it.ahmov_nro_cue_fec_ins on it.ah_movimientos_his(nro_cuenta,fec_insercion)
    tablespace it_ind parallel 10;
/
alter index it.ahmov_nro_cue_fec_ins parallel ( degree default );
/