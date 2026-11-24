CREATE OR REPLACE FUNCTION IT.fut_obt_lin_aprobada(p_cod_persona ba_personas.cod_persona%type) return number is
  v_fec_actual      date:= pag_cal.FU_OBT_FEC_ACTUAL(5);
  v_lin_aprobada    ge_pro_pre_aprobados.lin_nueva_tc%type;
  v_cod_cam_aum_lin_tar ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAM_AUM_LIN_TAR');
begin
  Begin
    select nvl(a.lin_nueva_tc,0)
      into v_lin_aprobada
      from ge_pro_pre_aprobados a
     where a.estado = 'V'
       and a.fec_vto_campana >= v_fec_actual
       and instr(','|| nvl(v_cod_cam_aum_lin_tar, 'x') ||',' ,  ','||a.cod_campana||',') > 0
       and a.cod_modulo = 5
       and a.cod_persona = p_cod_persona;
  exception
    when others then
       v_lin_aprobada := 0;
  end;

  return v_lin_aprobada;
end fut_obt_lin_aprobada;
/

