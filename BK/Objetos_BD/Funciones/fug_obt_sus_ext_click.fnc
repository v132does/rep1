CREATE OR REPLACE FUNCTION IT.FUG_OBT_SUS_EXT_CLICK
 (P_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE)
 RETURN VARCHAR2 IS
  v_ind_sus_ext_click varchar2(1);
  v_can_cta_tarjeta number;
  v_tip_ext_cliente number;
BEGIN
  begin
    select count(t.nro_cuenta)
      into v_can_cta_tarjeta
      from ge_cta_clientes c, ta_cta_tarjetas t, ge_cta_dat_adicionales d
     where c.cod_persona = p_cod_persona
       and c.relacion = 'P'
       and c.nro_cuenta = t.nro_cuenta
       and t.estado = 'N'
       and c.nro_cuenta = d.nro_cuenta
       and d.parametro = 'RET_EXTRACTO'
       and nvl(fug_obt_pardinamico('EXC_NOT_EXT_TAR',t.cod_modulo,t.cod_modalidad), 'N') <>'S'
       and d.val_parametro = 'S';
  exception 
    when others then
      v_can_cta_tarjeta := 0;
  end;
     
  begin
    select count(*)
      into v_tip_ext_cliente
      from ge_clientes cl
     where cl.cod_persona = p_cod_persona
       and cl.tip_extracto = 'N';
  exception
    when others then
      v_tip_ext_cliente := 0;
  end;
          
  if v_can_cta_tarjeta > 0 or v_tip_ext_cliente > 0 then 
    begin
      select 'S'
        into v_ind_sus_ext_click
        FROM bw_not_cli_suscriptos
       WHERE cod_persona = p_cod_persona
         and activo = 'S'
         and exists (select 1 from ge_reg_tip_extracto
                      where cod_persona = p_cod_persona
                        and tip_novedad = 'A'); 
    EXCEPTION
      WHEN OTHERS THEN
        v_ind_sus_ext_click := 'N';    
    END;
  else
    v_ind_sus_ext_click := 'N';
  end if; 
  
  RETURN nvl(v_ind_sus_ext_click, 'N');
END;
/

