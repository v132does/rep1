CREATE OR REPLACE PROCEDURE IT.PRG_CAN_PRE_APROBADO( p_cod_persona   in ge_pro_pre_aprobados.cod_persona%type,
                                                  p_nro_solicitud in ge_pro_pre_aprobados.nro_solicitud%type -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
                                                   ) IS
/*Cancela los pre-aprobados de préstamos que quedaron vigentes luego de la carga de solicitud--*/
----
--v_fec_actual date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
-- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
v_cod_modulo     ge_pro_pre_aprobados.cod_modulo%type;
v_cod_modalidad  ge_pro_pre_aprobados.cod_modalidad%type;
--
BEGIN
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
   -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
   -- Si el cliente toma un pre-aprobado distinto a las modalidades 65 y 68 se cancelará inmediatamente el pre-aprobado correspondiente a las modalidades 65 y 68 --
   begin
     select a.cod_modulo, a.cod_modalidad
       into v_cod_modulo, v_cod_modalidad
       from ge_pro_pre_aprobados a
      where a.cod_persona = p_cod_persona
        and a.nro_solicitud = p_nro_solicitud;
   exception
     when others then
       v_cod_modulo    := null;
       v_cod_modalidad := null;
   end;   
   if v_cod_modulo is not null and v_cod_modalidad is not null then
     if nvl(fug_obt_pardinamico('MOD_REC_PRE_APR',v_cod_modulo,v_cod_modalidad),'N') = 'N' then
       update ge_pro_pre_aprobados a
          set a.estado = 'C'
        where a.cod_persona = p_cod_persona
          and a.cod_modulo  = v_cod_modulo
          and a.estado = 'V'
          and a.nro_solicitud is null
          and nvl(fug_obt_pardinamico('MOD_REC_PRE_APR',a.cod_modulo,a.cod_modalidad),'N') = 'S';      
     end if;
   end if;
   --   
END;
/

