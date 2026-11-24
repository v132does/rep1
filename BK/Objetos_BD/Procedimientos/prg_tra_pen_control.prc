create or replace procedure it.prg_tra_pen_control is
  cursor c_pendientes(p_fec_actual in date) is(
    select *
      from ge_sol_tra_cuentas s
     where s.estado = 'P'
       and fec_vencimiento >= p_fec_actual);

  v_fec_actual        date := trunc(sysdate);
  v_fec_cal_actual    date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_texto             ge_par_dinamicos.val_parametro%type;
  v_ori_texto         ge_par_dinamicos.val_parametro%type;
  v_can_dia_restantes number;
  v_cod_error         number;
  v_men_error         varchar2(4000);
  v_link              ge_par_dinamicos.val_parametro%type;
  v_nom_cliente       ba_personas.nom_completo%type;

begin

  v_texto     := fug_obt_pardinamico('TXT_SMS_ENV_TRA_CONTACTO');
  v_ori_texto := v_texto;
  if nvl(v_texto, '0') = '0' then
    v_cod_error := 1;
    v_men_error := 'No se encuentra configurado parametro "TXT_SMS_ENV_TRA_CONTACTO"';
  end if;
  v_link := fug_obt_pardinamico('URL_DES_APP');
  if nvl(v_link, '0') = '0' then
    v_cod_error := 2;
    v_men_error := 'No se encuentra configurado parametro "URL_DES_APP"';
  end if;
  v_can_dia_restantes := 0;
  for rec in c_pendientes(v_fec_cal_actual) loop
    savepoint control;
    v_can_dia_restantes := rec.fec_vencimiento - v_fec_cal_actual;
    if v_can_dia_restantes > 0 then
      begin
        select initcap(p.pri_nombre || ' ' || p.pri_apellido)
          into v_nom_cliente
          from ba_per_fisicas p
         where p.cod_persona = rec.cod_persona;
      exception
        when no_data_found then
          v_cod_error := 3;
          v_men_error := 'No existe cliente cod.persona ' ||
                         rec.cod_persona;
        when others then
          v_cod_error := 3;
          v_men_error := substr('Ocurrio un error al buscar cliente cod.persona ' ||
                                rec.cod_persona || ' Error: ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
      end;
      if nvl(v_cod_error, 0) = 0 then
        v_texto := replace(replace(replace(v_texto,
                                           '$NOMBRE_CLIENTE',
                                           v_nom_cliente),
                                   '$LINK',
                                   v_link),
                           '$X',
                           to_char(v_can_dia_restantes));
        begin
          paa_alc.pr_env_not_sms(rec.nro_telefono,
                                 v_texto,
                                 v_cod_error,
                                 v_men_error);
        exception
          when others then
            v_cod_error := 3;
            v_men_error := substr('Ocurrio un error en el proceso de envio de sms al nro telefono: ' ||
                                  rec.nro_telefono || ' Error: ' ||
                                  DBMS_UTILITY.format_error_stack || ' - ' ||
                                  DBMS_UTILITY.format_error_backtrace,
                                  1,
                                  4000);
        end;
      end if;
    else
      begin
        update ge_sol_tra_cuentas c
           set estado = 'V'
         where c.nro_telefono = rec.nro_telefono
           and c.monto = rec.monto
           and c.nro_cta_debito = rec.nro_cta_debito
           and c.nro_transferencia = rec.nro_transferencia;
      exception
        when others then
          v_cod_error := 4;
          v_men_error := substr('Ocurrio un error al actualizar estado de la transferencia nro ' ||
                                rec.nro_transferencia || ' Error: ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
      end;
      if sql%rowcount = 0 and nvl(v_cod_error, 0) = 0 then
        v_cod_error := 4;
        v_men_error := 'No se actualizo el estado de la transferencia nro ' ||
                       rec.nro_transferencia;
      end if;
    end if;
    if nvl(v_cod_error, 0) != 0 then
      /*Si ocurre un error guarda en el log y hace rollback*/
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PRG_TRA_PEN_CONTROL',
                              substr('Telefono ' || rec.nro_telefono ||
                                     'Transferencia ' ||
                                     rec.nro_transferencia || ' Error: ' ||
                                     v_men_error,
                                     1,
                                     4000),
                              rec.cod_persona,
                              rec.nro_cta_debito);
      end if;
      rollback to control;
    else
      commit;
    end if;
    v_can_dia_restantes := 0;
    v_cod_error         := 0;
    v_texto             := v_ori_texto;
  end loop;
exception
  when others then
    v_cod_error := 5;
    v_men_error := substr('Ocurrió un error en el proceso de control de transferencias pendientes ' ||
                          ' Error: ' || DBMS_UTILITY.format_error_stack ||
                          ' - ' || DBMS_UTILITY.format_error_backtrace,
                          1,
                          4000);
   if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
    prg_ins_log_programas('PRG_TRA_PEN_CONTROL',
                          substr(' Error: ' || v_men_error, 1, 4000),
                          null,
                          null);
   end if;
end prg_tra_pen_control;
/

