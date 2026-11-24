create or replace procedure it.prs_snp_obt_tra_servicio( p_cod_servicio     in  ge_cob_servicios.cod_servicio%type,
                                                      p_cod_moneda       in  ge_cob_servicios.cod_moneda%type,
                                                      p_mto_cobro        out ge_movimientos.monto%type,
                                                      p_tab_cob_servicio out pas_snp.t_tab_cob_servicio
                                                     )
is
  cursor cu_cob_servicio ( p_cob_servicio in ge_cob_servicios.cod_servicio%type,
                           p_cod_moneda   in ge_cob_servicios.cod_moneda%type
                         ) is
  select *
    from ge_cob_servicios a
   where a.cod_servicio = p_cob_servicio
     and a.cod_moneda = p_cod_moneda
     and a.estado = 'P'
     and a.ref_numerico1 is null
     and a.monto > 0
     for update of a.cod_servicio, a.tip_cobro,
                   a.nro_operacion, a.monto;

  v_tab_cob_servicio pas_snp.t_tab_cob_servicio;
  v_indice      number := 0;
  v_tot_monto   ge_movimientos.monto%type := 0;
begin
  v_tab_cob_servicio.delete;

  for cs in cu_cob_servicio ( p_cod_servicio, p_cod_moneda ) loop
    v_indice  := v_tab_cob_servicio.count + 1;
    --
    v_tab_cob_servicio( v_indice ) := cs;
    --
    v_tot_monto := v_tot_monto + cs.monto;
    --

  end loop;
  --
  p_mto_cobro   := v_tot_monto;
  p_tab_cob_servicio := v_tab_cob_servicio;
  --
exception
  when others then
    --
    p_mto_cobro := 0;
    p_tab_cob_servicio.delete;
    --
    raise_application_error( -20001, 'Error en PRS_SNP_OBT_TRA_SERVICIO para código de servicio ' || p_cod_servicio ||
                                     ' Moneda '|| p_cod_moneda||': ' || sqlerrm
                           );
end prs_snp_obt_tra_servicio;
/

