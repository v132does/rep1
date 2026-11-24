CREATE OR REPLACE PROCEDURE IT.PRW_NOT_EXTRACTOS (p_fec_extracto IN DATE DEFAULT NULL) is
  v_cod_modulo     ba_modulos.cod_modulo%type := 4;
  v_fec_anterior   ge_calendarios.fec_anterior%type := nvl(trunc(p_fec_extracto), pag_cal.fu_obt_fec_anterior(v_cod_modulo));
  v_retorno        number;
  -- para notificar
  v_cod_evento     bw_not_eventos.cod_evento%TYPE;
  v_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE := 'EXTRDIGIT';
  v_template       bw_not_tip_eventos.template%TYPE;
  v_mensaje        bw_not_mensajes.mensaje%TYPE;

  -- selector de clientes a notificar
  cursor c_personas is
     select c.cod_persona
       from ge_clientes c, ba_personas p
      where c.tip_extracto = 'N' -- no imprimen extractos
        and c.cod_persona = p.cod_persona
        and p.tipo = 'F' -- personas fisicas
        and exists ( select 1
                       from ge_ext_clientes ex
                      where ex.fec_extracto = v_fec_anterior
                        and ex.fre_extracto = 'M'
                        and ex.cod_persona = c.cod_persona
                        and ex.tip_impresion = 'N' -- DYDMR-6268 -- 03/2017 -- Solo tipo de Impresion = No impreso
                     );
        --and nvl(paw_not.fu_obt_sus_ext_clic(c.cod_persona),'N') = 'S';
begin
   if pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo) = pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(v_cod_modulo) or p_fec_extracto is not null then
      -- obtenemos el template de notificacion
      if paw_not.fu_obt_not_template(v_cod_tip_evento, v_template, '00') <> 0 then
         raise_application_error(-20000, 'No existe template para notificacion de extractos de cuentas');
      end if;
      -- formateamos el mensaje
      v_mensaje := utl_lms.format_message(v_template, to_char(v_fec_anterior, 'dd/mm/yyyy'));
      -- obtenemos codigo de evento
      v_cod_evento := paw_not.fu_obt_cod_evento(v_cod_tip_evento);
      if v_cod_evento <= 0 then
        raise_application_error(-20001, 'No existe codigo de evento para notificacion de extractos de cuentas');
      end if;
      -- registro de notificacion de extracto
      for pe in c_personas loop
         if paw_not.fu_obt_cli_des_activo(pe.cod_persona) is not null      -- Destino Activo
           and nvl(paw_not.fu_obt_suscripcion(pe.cod_persona),'N') = 'S'   -- DYDMR-6123 -- 02/2017 -- Suscrito a Notificaciones
             and nvl(paw_not.fu_obt_sus_ext_clic(pe.cod_persona),'N') = 'S' then -- DYDMR-6268 -- 03/2017 -- Suscrito a Extracto Clic
                v_retorno := paw_not.fu_ins_mensaje(v_cod_evento, v_cod_tip_evento, v_mensaje, pe.cod_persona, '0', NULL, 'S');
         end if;
      end loop;
   end if;
/*exception
   when others then
      prg_env_mail('bbvanet@bbva.com', 'ep.py@bbva.com', '[PRW_NOT_EXTRACTOS] Error en notificacion', SQLERRM);*/
end;
/

