CREATE OR REPLACE FUNCTION IT.FUT_VAL_AUM_PRE_APROBADOS(p_cod_persona ba_personas.cod_persona%type, -- Codigo de la persona
                                                     p_lin_credito ta_sol_lineas.lin_credito%type, --Nueva Linea de Crédito
                                                     p_nro_cuenta  ta_cta_tarjetas.nro_cuenta%type,
                                                     p_nro_solicitud ta_sol_lineas.nro_solicitud%type) return varchar2 is
/**
  ----
  -- Author  : GCAPO
  -- Created : 16/11/2018
  -- Purpose : Función para verificar si el cliente cuenta con un pre aprobado para el aumento de lineas de TC
**/
  v_result          varchar2(1) := 'N';
  v_fec_actual      date:= pag_cal.FU_OBT_FEC_ACTUAL(5);
  v_lin_credito     ta_cta_tarjetas.lin_credito%type := fug_obt_lin_cre_tarjeta(p_nro_cuenta);
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
        when no_data_found then
          v_result := 'N';
          return v_result;
    end;
    v_lin_aprobada := v_lin_aprobada + v_lin_credito;

    if p_lin_credito <= v_lin_aprobada then
      if p_nro_solicitud <> 0 then
       begin
         update ge_pro_pre_aprobados
            set estado = 'C',
                nro_solicitud = p_nro_solicitud
          where estado = 'V'
            and fec_vto_campana >= v_fec_actual
            and instr(','|| nvl(v_cod_cam_aum_lin_tar, 'x') ||',' ,  ','||cod_campana||',') > 0
            and cod_modulo = 5
            and cod_persona = p_cod_persona;
       exception
         when others then
           v_result := 'N';
           return v_result;
        end;
     end if;
       v_result := 'S';
    else
        v_result := 'N';
    end if;

  return v_result;
exception
 when others then
   return v_result;
end FUT_VAL_AUM_PRE_APROBADOS;
/

