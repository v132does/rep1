CREATE OR REPLACE PROCEDURE IT.PRG_PRO_IMPAGOS
 IS
 v_fec_actual      ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(4);
 v_cod_campanas    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAM_REN_LIN_SOB');
 v_cod_cam_cta_com ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAM_CTA_COMERCIO');
 v_msj                  varchar2(250);
 v_existe varchar2(1);
 CURSOR c_cuentas is
   SELECT mes, ano, c.cod_modulo, c.cod_modalidad, c.nro_cuenta,
          c.dia_mora dias_mora, c.cod_persona, l.nro_secuencia, l.fec_inicio, l.fec_vencimiento
     FROM cc_lin_sobregiros l, ge_cta_clientes cl, ge_cta_dia_mor_tmp c
    WHERE to_date('01/'||mes||'/'||ano, 'DD/MM/YYYY') >= add_months(v_fec_actual, -13)
      and cl.nro_cuenta = c.nro_cuenta
      and cl.relacion = 'P'
      and cl.cod_persona = l.cod_persona
      and l.nro_sec_padre is null
      and l.estado = 'A'
      and (instr(','|| v_cod_campanas ||',' ,  ','||l.cod_campana||',') > 0 
           or (instr(','|| v_cod_cam_cta_com ||',' ,  ','||l.cod_campana||',') > 0))
      and not exists (select 1
                        from cc_lin_sobregiros ls, cc_cta_corrientes cc
                       where ls.nro_sec_padre = l.nro_secuencia
                         and ls.nro_cuenta = cc.nro_cuenta
                         and cc.cod_ente is not null);
  v_mes number;
  v_can_mes_borrado number := nvl(fug_obt_pardinamico('CAN_MES_BOR_DIA_MOR_TMP'), 15);
  v_sentencia varchar2(2000);
BEGIN
  begin
     sql_util.ejecute_dml('TRUNCATE TABLE GE_CTA_DIA_MOR_IMPAGOS', v_msj);
     IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, 'No se ha podido eliminar los datos de la tabla de impagos. '||v_msj);
     END IF;
  end;
  For c in c_cuentas Loop
        begin
         v_mes := 12 - MONTHS_BETWEEN(add_months(trunc(v_fec_actual, 'mm'),-1),trunc(to_date('01/'||c.mes||'/'||c.ano, 'dd/mm/yyyy'), 'mm'));
       exception
         when others then
           v_mes := 0;
       end;

       if v_mes between 1 and 12 then
         begin
           select 'S'
             into v_existe
             from GE_CTA_DIA_MOR_IMPAGOS
            where nro_cuenta = c.nro_cuenta;
         exception
           when others then
              v_existe := 'N';
         END;

         IF nvl(V_EXISTE, 'N') = 'N' THEN
           begin
             v_sentencia := 'insert into GE_CTA_DIA_MOR_IMPAGOS ( cod_modulo,
                                                                  cod_modalidad,
                                                                  nro_cuenta,
                                                                  cod_persona,
                                                                  nro_lin_sobregiro,
                                                                  fec_inicio,
                                                                  fec_vencimiento,
                                                                  dia_mor_mes'||v_mes||')
                                                           values( '||c.cod_modulo||', '||
                                                                    c.cod_modalidad||', '||
                                                                   ''''||c.nro_cuenta||''','||
                                                                   c.cod_persona||', '||
                                                                   c.nro_secuencia||', '||
                                                                   'to_date('''||to_char(c.fec_inicio, 'DD/MM/YYYY')||''', '''||'DD/MM/YYYY''),'||
                                                                   'to_date('''||to_char(c.fec_vencimiento, 'DD/MM/YYYY')||''', '''||'DD/MM/YYYY''),'||
                                                                   c.dias_mora||')';
             execute Immediate v_sentencia;
           exception
             when others then
               RAISE_APPLICATION_ERROR( -20000, 'No se ha podido insertar el registro de impago de la cuenta '||c.nro_cuenta ||'. '|| sqlerrm );
           end;

         ELSE
           begin
             v_sentencia := 'update GE_CTA_DIA_MOR_IMPAGOS set DIA_MOR_MES'||v_mes||' = '||c.dias_mora||
                            ' where nro_cuenta = '||''''||c.nro_cuenta||''' and nro_lin_sobregiro = '|| c.nro_secuencia ||' and nvl(DIA_MOR_MES'||v_mes||',0) < '||c.dias_mora;
             Execute Immediate v_sentencia;
           exception
             when others then
               RAISE_APPLICATION_ERROR( -20000, 'No se ha podido actualizar el registro de impago de la cuenta '||c.nro_cuenta ||'. '|| sqlerrm );
           end;
         END IF;
       end if;

  end loop;

  BEGIN
    delete from ge_cta_dia_mor_tmp
     where to_date('01/'||mes||'/'||ano, 'DD/MM/YYYY') < add_months(v_fec_actual, (v_can_mes_borrado)*-1);
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR( -20000, 'No se ha podido eliminar el registro temporal de impagos. '|| sqlerrm );
  END;

  BEGIN
    update ge_par_dinamicos
       set val_parametro = to_char(v_fec_actual, 'dd/mm/yyyy')
     where parametro = 'FEC_ANT_PRO_IMPAGOS';
  exception
    when others then
      RAISE_APPLICATION_ERROR( -20000, 'No se ha podido actualizar la fecha anterior del proceso de Impagos. '|| sqlerrm );
  end;
  commit;
  PRG_GEN_LIN_CTA_COMERCIO; -- GENERA LA LÍNEA DE SOBREGIROS DE CUENTA COMERCIO
  commit;
  PRG_ENV_MAI_CTA_COMERCIO; -- ENVIA MAIL POR LA GENERACIÓN DE LAS LÍNEAS
  commit;
  PRG_GEN_REN_LIN_SOB; -- RENOVACIÓN DE LÍNEAS DE SOBREGIRO
  commit;
  PRG_ENV_MAI_CAN_LIN_SOB; -- ENVIO DE MAIL POR LA NO RENOVACIÓN O CANCELACIÓN
EXCEPTION
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'Error en el Proceso - Registro de Impagos: ' || sqlerrm );
END;
/

