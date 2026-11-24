CREATE OR REPLACE PROCEDURE IT.PRA_VER_LIB_RET_MASIVO IS

   --Variables Trabajo--
   v_fec_actual      DATE;
   v_error           varchar2(4000) := '';
   v_nro_cta_detalle ah_retenciones.nro_cuenta%type;
   v_sal_actualizar  ah_cta_vistas.sal_retenido%type;
   v_aho_negativo    varchar2(2000);
   v_can_negativo    number(6);
   v_det_cta_error   varchar2(200);
   v_can_cta_error   number(6);  
   v_val_parametro   ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('NRO_CTA_EXC_LIB_RET'),'0');
   --Cursor Principal--
   CURSOR c_ah_ret_x_cta IS      
     SELECT ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, nvl(x.sal_retenido, 0) sal_ret_cta,
       sum(nvl(ah_retenciones.sal_retenido,0)) sal_ret_bol, count(*) can_bol
        FROM ah_retenciones, ah_cta_vistas x
      where liberado  = 'N'
      AND ah_retenciones.cod_modulo IN (3, 4)
      and ((fec_final <= v_fec_actual) or (lib_posterior = 'S'))
      and x.nro_cuenta = ah_retenciones.nro_cuenta
      and not exists (select 1
            from cj_movimientos c
                      where c.fecha         = ah_retenciones.fec_inicio
                        and c.cod_usuario   = ah_retenciones.cod_usuario
            and c.estado       = 'X'
            and c.nro_cuenta    = ah_retenciones.nro_cuenta
            and c.cod_moneda    = ah_retenciones.cod_moneda
            and c.nro_documento = ah_retenciones.nro_documento
            and c.monto     = ah_retenciones.monto)
      and instr(v_val_parametro, x.nro_cuenta) = 0
      group by ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, x.sal_retenido
      having sum(nvl(ah_retenciones.sal_retenido,0)) > nvl(x.sal_retenido, 0)
      union all
      SELECT ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, nvl(x.sal_retenido, 0) sal_ret_cta,
       sum(nvl(ah_retenciones.sal_retenido,0)) sal_ret_bol, count(*) can_bol
        FROM ah_retenciones, cc_cta_corrientes x
      where liberado  = 'N'
      AND ah_retenciones.cod_modulo IN (3, 4)
      and ((fec_final <= v_fec_actual) or (lib_posterior = 'S'))
      and x.nro_cuenta = ah_retenciones.nro_cuenta
      and not exists (select 1
            from cj_movimientos c
                      where c.fecha         = ah_retenciones.fec_inicio
                        and c.cod_usuario   = ah_retenciones.cod_usuario
            and c.estado       = 'X'
            and c.nro_cuenta    = ah_retenciones.nro_cuenta
            and c.cod_moneda    = ah_retenciones.cod_moneda
            and c.nro_documento = ah_retenciones.nro_documento
            and c.monto     = ah_retenciones.monto)
      and instr(v_val_parametro, x.nro_cuenta) = 0
      group by ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, x.sal_retenido
      having sum(nvl(ah_retenciones.sal_retenido,0)) > nvl(x.sal_retenido, 0)
      union all
      SELECT ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, nvl(x.sal_retenido, 0) sal_ret_cta,
       sum(nvl(ah_retenciones.sal_retenido,0)) sal_ret_bol, count(*) can_bol
        FROM ah_retenciones, cc_cta_bancarias x
      where liberado  = 'N'
      AND ah_retenciones.cod_modulo IN (3, 4)
      and ((fec_final <= v_fec_actual) or (lib_posterior = 'S'))
      and x.nro_cuenta = ah_retenciones.nro_cuenta
      and not exists (select 1
            from cj_movimientos c
                      where c.fecha         = ah_retenciones.fec_inicio
                        and c.cod_usuario   = ah_retenciones.cod_usuario
            and c.estado       = 'X'
            and c.nro_cuenta    = ah_retenciones.nro_cuenta
            and c.cod_moneda    = ah_retenciones.cod_moneda
            and c.nro_documento = ah_retenciones.nro_documento
            and c.monto     = ah_retenciones.monto)
      and instr(v_val_parametro, x.nro_cuenta) = 0
      group by ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, x.sal_retenido
      having sum(nvl(ah_retenciones.sal_retenido,0)) > nvl(x.sal_retenido, 0)
      union all
      SELECT ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, nvl(x.sal_retenido, 0) sal_ret_cta,
       sum(nvl(ah_retenciones.sal_retenido,0)) sal_ret_bol, count(*) can_bol
        FROM ah_retenciones, ah_cta_certificados x
      where liberado  = 'N'
      AND ah_retenciones.cod_modulo IN (3, 4)
      and ((fec_final <= v_fec_actual) or (lib_posterior = 'S'))
      and x.nro_cuenta = ah_retenciones.nro_cuenta
      and not exists (select 1
            from cj_movimientos c
                      where c.fecha         = ah_retenciones.fec_inicio
                        and c.cod_usuario   = ah_retenciones.cod_usuario
            and c.estado       = 'X'
            and c.nro_cuenta    = ah_retenciones.nro_cuenta
            and c.cod_moneda    = ah_retenciones.cod_moneda
            and c.nro_documento = ah_retenciones.nro_documento
            and c.monto     = ah_retenciones.monto)
      and instr(v_val_parametro, x.nro_cuenta) = 0
      group by ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, x.sal_retenido
      having sum(nvl(ah_retenciones.sal_retenido,0)) > nvl(x.sal_retenido, 0)
      union all
      SELECT ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, nvl(x.sal_retenido, 0) sal_ret_cta,
       sum(nvl(ah_retenciones.sal_retenido,0)) sal_ret_bol, count(*) can_bol
        FROM ah_retenciones, ah_cta_plazos x
      where liberado  = 'N'
      AND ah_retenciones.cod_modulo IN (3, 4)
      and ((fec_final <= v_fec_actual) or (lib_posterior = 'S'))
      and x.nro_cuenta = ah_retenciones.nro_cuenta
      and not exists (select 1
            from cj_movimientos c
                      where c.fecha         = ah_retenciones.fec_inicio
                        and c.cod_usuario   = ah_retenciones.cod_usuario
            and c.estado       = 'X'
            and c.nro_cuenta    = ah_retenciones.nro_cuenta
            and c.cod_moneda    = ah_retenciones.cod_moneda
            and c.nro_documento = ah_retenciones.nro_documento
            and c.monto     = ah_retenciones.monto)
      and instr(v_val_parametro, x.nro_cuenta) = 0
      group by ah_retenciones.nro_cuenta, ah_retenciones.cod_modulo, ah_retenciones.cod_modalidad, x.sal_retenido
      having sum(nvl(ah_retenciones.sal_retenido,0)) > nvl(x.sal_retenido, 0);
  
  ---Procedimiento para concatenar Mensaje a Desplegar por Error
  procedure lp_car_msj_error(p_msj_error in varchar2) is
  begin
    if v_error is null then
      v_error := p_msj_error;
    else
      v_error := substr(v_error ||'-'|| p_msj_error,1,4000);
    end if;
  end;
   
 --DESOPIMI-62 - Optimizar tratamiento de error en Liberación de Retenciones (PRA_LIB_RETENCION) - DYD-SDSL-3454
 PROCEDURE lp_tra_env_email(p_error varchar2) IS
     v_para       VARCHAR2(4000);
     -- Variables para mail
     v_asunto     VARCHAR2(2000);
     v_texto      VARCHAR2(4000) := p_error;
     v_hin_mail ge_ra_log_mail.hor_inicio%type;
     v_hfi_mail ge_ra_log_mail.hor_fin%type;
     v_det_error ge_ra_log_mail.det_error%type;
     
     PRAGMA AUTONOMOUS_TRANSACTION;     
     
   BEGIN     
         v_asunto   := 'Error: VERIFICACIONES CIERRE LIB. RETENCION (11-36-pra_ver_lib_retencion)- Fecha '||to_char(v_fec_actual, 'DD/MM/YYYY');
       
         BEGIN
             v_hin_mail := to_char(sysdate, 'hh24:mi:ss');

             v_para := fug_obt_pardinamico('ENV_EMA_GUA_CIERRE');

             it_mail.mail(fug_obt_dir_correo,
                          v_para,
                          v_asunto,
                          v_texto);

             v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
             commit;
         EXCEPTION
            when others then
               v_det_error := substr(sqlerrm, 1, 4000);
               INSERT INTO ge_ra_log_mail (fec_envio,
                                           nom_archivo,
                                           dir_correo,
                                           mensaje,
                                           det_error,
                                           hor_inicio,
                                           hor_fin)
                                   VALUES (SYSDATE,
                                           null,
                                           v_para,
                                           v_asunto||'-'|| v_texto,
                                           v_det_error,
                                           v_hin_mail,
                                           v_hfi_mail);

        commit;
        END;
        
   END lp_tra_env_email;

--- Inicio del proceso principal
BEGIN     
   v_fec_actual := pag_cal.fu_obt_fec_actual(3);
   v_det_cta_error := null;
   v_can_cta_error := 0;
   for cta in c_ah_ret_x_cta loop
       v_nro_cta_detalle := cta.nro_cuenta;
       v_can_negativo := 0;
       v_aho_negativo := null;
       v_sal_actualizar := nvl(cta.sal_ret_cta,0) - nvl(cta.sal_ret_bol,0);       
       v_can_cta_error := nvl(v_can_cta_error,0) + 1;
       v_aho_negativo := v_aho_negativo||'Cta: '||v_nro_cta_detalle||
                        ' - Liberar: '||to_char(abs(v_sal_actualizar));
       lp_car_msj_error('Sal.Ret. Negativo, Verificar: '||v_aho_negativo);      
       if length(nvl(v_det_cta_error,'0')) <= 180 then
          if v_det_cta_error is null then
             v_det_cta_error := v_nro_cta_detalle;
          else
             v_det_cta_error:= v_det_cta_error||','||v_nro_cta_detalle;
          end if;
       end if;
   end loop;
   -- si hay mensajes de error
   if v_det_cta_error is not null then        
       lp_tra_env_email(v_error);
      begin
        update ge_par_dinamicos
           set val_parametro = v_det_cta_error
         where parametro = 'NRO_CTA_EXC_LIB_RET';
        if sql%notfound then
          insert into ge_par_dinamicos
            (parametro, val_parametro)
          values
            ('NRO_CTA_EXC_LIB_RET', v_det_cta_error);
        end if;
      exception
        when others then
          v_error := substr(sqlerrm,1,4000);
          prg_ins_log_errores('PRA_VER_LIB_RET_MASIVO',v_error,'NRO_CUENTA',v_det_cta_error);
      end;
   end if;       
EXCEPTION 
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20001, ' Error en PRA_VER_LIB_RETENCION '|| SQLERRM);
      END IF;
END;
/
