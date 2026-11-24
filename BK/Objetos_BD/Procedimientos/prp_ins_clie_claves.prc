create or replace procedure it.prp_ins_clie_claves is
       cursor c_clien is
              select *
                from bw_gen_claves_tmp a
               order by a.nro_orden ;
v_nro_lote bw_ope_claves.nro_lote%type := 0 ;
v_fec_actual    date := pag_cal.fu_obt_fec_actual(1); 
begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; end ;
  Begin
     select nvl(max(nro_lote), 0)
       into v_nro_lote
	     from bw_gen_claves;
	     v_nro_lote := v_nro_lote + 1;
	exception
		when no_data_found then
		   v_nro_lote := 1;
		when others then
		   v_nro_lote := 1;
	End;
  for x in c_clien loop
      begin
        insert into bw_gen_claves(cod_persona,
                                  nro_lote,
                                  nro_orden,
                                  estado,
                                  fec_inser_lote)
                            values(x.cod_persona,
                                   v_nro_lote,
                                   x.nro_orden,
                                   'I',
                                   v_fec_actual) ;
      exception
        when others then
          null ;
      end ;
  end loop ;
end ;
/

